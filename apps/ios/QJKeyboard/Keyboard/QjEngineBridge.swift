//
//  QjEngineBridge.swift
//  青简 Rust 内核的 Swift 封装：线程安全、自动管理内存、把 JSON 候选解码成 Swift 模型。
//

import Foundation

/// 单条候选。M0 只取上屏文本；不声明 `kind` 字段，避免个别枚举的特殊 JSON 形态导致整批解码失败。
private struct QjCandidate: Decodable {
    let text: String
}

/// `qj_engine_query` 返回的 JSON。
private struct QjQueryResult: Decodable {
    let ok: Bool
    let preedit: String?
    let tail: String?
    let candidates: [QjCandidate]?
    let error: String?
}

/// 供 UI 使用的查询结果。
struct QjQuery {
    let preedit: String
    let candidates: [String]
}

/// 对 Rust 引擎的单例封装。所有方法应在同一串行队列（UI 线程）调用。
final class QjEngineBridge {
    static let shared = QjEngineBridge()

    private var handle: OpaquePointer?
    private(set) var loadError: String?

    private init() {}

    deinit {
        if let h = handle {
            qj_engine_free(h)
            handle = nil
        }
    }

    /// 懒加载引擎。资源在扩展 bundle 的 Resources 目录；学习数据写在扩展私有 Documents。
    @discardableResult
    func setupIfNeeded() -> Bool {
        if handle != nil { return true }

        let fm = FileManager.default

        // 资源目录：优先蓝色文件夹引用构建出的 Resources/，回退到 bundle 根。
        let bundlePath = Bundle.main.bundlePath
        let resInResources = (bundlePath as NSString).appendingPathComponent("Resources")
        var resDir = resInResources
        let dictInResources = (resInResources as NSString).appendingPathComponent("dict.qj")
        if !fm.fileExists(atPath: dictInResources) {
            resDir = bundlePath
        }

        let writableDir: String
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            writableDir = docs.path
        } else {
            writableDir = NSTemporaryDirectory()
        }
        try? fm.createDirectory(atPath: writableDir, withIntermediateDirectories: true)

        let lang = "en"
        let created = resDir.withCString { rcs in
            writableDir.withCString { wcs in
                lang.withCString { lcs in
                    qj_engine_new(rcs, wcs, lcs)
                }
            }
        }
        handle = created
        if created == nil {
            loadError = "引擎初始化失败，请确认词库资源已随包打包。"
            return false
        }
        return true
    }

    /// 整段替换拼音串。
    func setInput(_ text: String) {
        guard let h = handle else { return }
        text.withCString { cstr in
            qj_engine_set_input(h, cstr)
        }
    }

    func clear() {
        guard let h = handle else { return }
        qj_engine_clear(h)
    }

    /// 查询候选；失败返回 nil。
    func query() -> QjQuery? {
        guard let h = handle, let cjson = qj_engine_query(h) else { return nil }
        defer { qj_string_free(cjson) }
        guard let raw = String(validatingUTF8: cjson),
              let data = raw.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(QjQueryResult.self, from: data),
              parsed.ok else {
            return nil
        }
        let texts = (parsed.candidates ?? []).map { $0.text }
        return QjQuery(preedit: parsed.preedit ?? "", candidates: texts)
    }

    /// 上屏第 index 个候选，返回上屏文本；无候选返回空串。
    func commit(_ index: Int) -> String {
        guard let h = handle, let c = qj_engine_commit(h, index) else { return "" }
        defer { qj_string_free(c) }
        return String(validatingUTF8: c) ?? ""
    }

    /// 原样上屏（英文直出 / 回车）。
    func commitRaw() -> String {
        guard let h = handle, let c = qj_engine_commit_raw(h) else { return "" }
        defer { qj_string_free(c) }
        return String(validatingUTF8: c) ?? ""
    }

    func setTraditional(_ on: Bool) {
        guard let h = handle else { return }
        qj_engine_set_traditional(h, on ? 1 : 0)
    }

    func flush() {
        guard let h = handle else { return }
        qj_engine_flush(h)
    }
}
