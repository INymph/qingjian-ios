//! 引擎装配与线程安全封装。
//!
//! 平台无关内核与 iOS 键盘之间的“业务层”：把各桌面壳通用的装配逻辑
//! （主词库 + 学习器 + 译词 + 英文词 + 二元语言模型）收敛成一次构造，
//! 再把查询/上屏收敛成几个窄方法。C ABI 导出在 `lib.rs`，本文件不出现 `extern`。

use std::path::PathBuf;
use std::sync::{Mutex, MutexGuard};

use qingjian_core::{Candidate, Engine, Language, TraditionalVariant};
use qingjian_dictionary::{Dictionary, WordList};
use qingjian_learning::FrequencyLearner;
use qingjian_lm::BigramModel;
use qingjian_translate::Glossary;

/// 对外引擎句柄。内部加锁：键盘扩展调用基本都在 UI 串行队列，锁无竞争；
/// 加锁是为了让裸指针持有的状态在多线程下也安全（满足跨 FFI 的互斥访问）。
pub struct QjEngine {
    inner: Mutex<Inner>,
}

struct Inner {
    engine: Engine,
    /// 最近一次 query 的候选，commit 按序号取回完整对象（上屏与学习依赖完整 Candidate）。
    last: Vec<Candidate>,
}

/// 装配引擎。
///
/// - `resources`：只读资源目录（在扩展 bundle 内），含 `dict.qj` / `glossary-*.tsv` / `lm.qj` 等；
/// - `writable`：扩展私有可写目录（学习数据落盘）；
/// - `lang_code`：译词语言 ISO 代码（`en`/`ja`/…），无法识别时回退英语。
pub fn build(resources: &str, writable: &str, lang_code: &str) -> Result<QjEngine, String> {
    let resources = PathBuf::from(resources);
    let writable = PathBuf::from(writable);
    let _ = std::fs::create_dir_all(&writable);

    let language: Language = lang_code.parse().unwrap_or(Language::English);

    // 主词库：优先打包后的 .qj（mmap、只读、零拷贝），回退到源 TSV。
    let dict_path = ["dict.qj", "dict.tsv"]
        .into_iter()
        .map(|name| resources.join(name))
        .find(|p| p.exists())
        .ok_or_else(|| format!("resources 目录下找不到 dict.qj / dict.tsv：{resources:?}"))?;
    let dictionary =
        Dictionary::from_path(&dict_path).map_err(|e| format!("词库加载失败 {dict_path:?}: {e}"))?;

    // 学习器：文件不存在时返回空表（首次运行正常），flush 时写回同一目录。
    let learner_path = writable.join("user-frequency.tsv");
    let learner = FrequencyLearner::from_path(&learner_path)
        .map_err(|e| format!("学习器初始化失败：{e}"))?;

    let mut engine = Engine::new(dictionary).with_learner(Box::new(learner));

    // 译词表（随包只读，可选）：glossary-<语言>.tsv
    let gloss_path = resources.join(format!("glossary-{}.tsv", language.code()));
    if gloss_path.exists() {
        match Glossary::from_path(language, &gloss_path) {
            Ok(glossary) => engine = engine.with_translator(Box::new(glossary)),
            Err(e) => eprintln!("[qingjian] 译词表加载失败 {gloss_path:?}: {e}"),
        }
    }

    // 英文候选词表（可选，中文输入下的英文补全）。
    let english_path = resources.join("english.tsv");
    if english_path.exists() {
        match WordList::from_path(&english_path) {
            Ok(words) => engine = engine.with_english(words),
            Err(e) => eprintln!("[qingjian] 英文词表加载失败：{e}"),
        }
    }

    // 二元整句语言模型（可选，轻量）；神经重打分未启用时由它做整句排序。
    let lm_path = resources.join("lm.qj");
    if lm_path.exists() {
        match BigramModel::from_path(&lm_path) {
            Ok(model) => engine = engine.with_language_model(Box::new(model)),
            Err(e) => eprintln!("[qingjian] 语言模型加载失败：{e}"),
        }
    }

    engine.set_full_width_punctuation(true);

    Ok(QjEngine {
        inner: Mutex::new(Inner {
            engine,
            last: Vec::new(),
        }),
    })
}

impl QjEngine {
    fn lock(&self) -> MutexGuard<'_, Inner> {
        self.inner.lock().unwrap_or_else(|poison| poison.into_inner())
    }

    /// 整段替换当前拼音串。M0 全拼场景下与逐键 push 等价；
    /// Swift 端维护完整拼音串，每次按键后整体传入即可。
    pub fn set_input(&self, input: &str) {
        self.lock().engine.set_input(input);
    }

    pub fn clear(&self) {
        self.lock().engine.clear();
    }

    /// 查询并返回 JSON；同时缓存候选供 commit_index 使用。
    /// 失败时返回 `{"ok":false,"error":...}`。
    pub fn query(&self) -> String {
        let mut g = self.lock();
        let mut query = match g.engine.query() {
            Ok(q) => q,
            Err(e) => {
                return serde_json::json!({ "ok": false, "error": e.to_string() }).to_string();
            }
        };
        // query 本身不带译文，这里补一次标注，候选里才有 translation。
        let _report = g.engine.annotate(&mut query.candidates);
        let preedit = query.marked_text();
        let tail = query.tail.clone();
        let items = query.candidates.items.clone();
        g.last = items.clone();
        serde_json::json!({
            "ok": true,
            "preedit": preedit,
            "tail": tail,
            "candidates": items,
        })
        .to_string()
    }

    /// 上屏最近一次 query 的第 `index` 个候选（从 0 开始），返回上屏文本。
    pub fn commit_index(&self, index: usize) -> Option<String> {
        let mut g = self.lock();
        let candidate = g.last.get(index)?.clone();
        g.last.clear();
        Some(g.engine.commit(&candidate))
    }

    /// 原样上屏缓冲区内容（英文直出 / 回车）。
    pub fn commit_raw(&self) -> String {
        let mut g = self.lock();
        g.last.clear();
        g.engine.take_raw()
    }

    /// 学习数据落盘（键盘收起、应用进入后台时调用）。
    pub fn flush(&self) {
        self.lock().engine.learner_mut().flush();
    }

    /// 繁体输出开关（标准简体 / 繁体）。
    pub fn set_traditional(&self, on: bool) {
        self.lock().engine.set_traditional(if on {
            TraditionalVariant::Standard
        } else {
            TraditionalVariant::Off
        });
    }
}
