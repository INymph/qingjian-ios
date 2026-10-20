//! 青简 iOS 桥接 crate：对 Swift 暴露极简 C ABI。
//!
//! 设计约束：
//! - 只用 `#[no_mangle] extern "C"` 的平坦接口，不跨 FFI 传 Rust 所有权，引擎用不透明句柄；
//! - 所有跨 FFI 函数都用 `catch_unwind` 兜底，Rust 侧 panic 绝不展开进 Swift（那是 UB）；
//! - 出参字符串由 Rust 用 `CString` 分配，Swift 复制后必须调用 [`qj_string_free`] 归还；
//! - 本 crate 是纯 Rust 内核，无任何平台 API，可直接交叉编译到 `aarch64-apple-ios`。

mod engine;

pub use engine::build;
pub use engine::QjEngine;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic::{catch_unwind, AssertUnwindSafe};

/// 把 C 字符串指针安全转成 `&str`；空指针或非法 UTF-8 返回 `None`。
///
/// # Safety
/// 调用方保证 `p` 为 null，或指向以 `\0` 结尾、在调用期间有效的字节串。
unsafe fn c_str<'a>(p: *const c_char) -> Option<&'a str> {
    if p.is_null() {
        None
    } else {
        // SAFETY: 调用方保证 `p` 指向以 `\0` 结尾、调用期间有效的字节串。
        unsafe { CStr::from_ptr(p).to_str().ok() }
    }
}

/// 把 Rust `String` 转成需要调用方释放的 C 字符串；空串映射为 null。
fn into_c_string(s: String) -> *mut c_char {
    if s.is_empty() {
        return std::ptr::null_mut();
    }
    match CString::new(s) {
        Ok(c) => c.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

/// 创建引擎。失败返回 null（可在构建日志里看到原因）。
///
/// - `resources_dir`：bundle 内只读资源目录（UTF-8）；
/// - `writable_dir`：扩展私有可写目录（UTF-8）；
/// - `lang_code`：译词语言代码（如 `en`）。
#[unsafe(no_mangle)]
pub extern "C" fn qj_engine_new(
    resources_dir: *const c_char,
    writable_dir: *const c_char,
    lang_code: *const c_char,
) -> *mut QjEngine {
    let result = catch_unwind(AssertUnwindSafe(|| unsafe {
        let resources = c_str(resources_dir)?;
        let writable = c_str(writable_dir)?;
        let lang = c_str(lang_code).unwrap_or("en");
        let engine = build(resources, writable, lang).ok()?;
        Some(Box::into_raw(Box::new(engine)))
    }));
    match result {
        Ok(Some(ptr)) => ptr,
        Ok(None) => std::ptr::null_mut(),
        Err(_) => std::ptr::null_mut(),
    }
}

/// 销毁引擎。
///
/// # Safety
/// `engine` 必须是 [`qj_engine_new`] 返回且未被释放过的句柄；允许传 null。
#[unsafe(no_mangle)]
pub extern "C" fn qj_engine_free(engine: *mut QjEngine) {
    let _ = catch_unwind(AssertUnwindSafe(|| unsafe {
        if !engine.is_null() {
            drop(Box::from_raw(engine));
        }
    }));
}

/// 整段替换当前拼音串。
///
/// # Safety
/// 同 [`qj_engine_free`]；`input` 为合法 UTF-8 C 字符串。
#[unsafe(no_mangle)]
pub extern "C" fn qj_engine_set_input(engine: *mut QjEngine, input: *const c_char) {
    let _ = catch_unwind(AssertUnwindSafe(|| unsafe {
        if let (Some(e), Some(text)) = (engine.as_ref(), c_str(input)) {
            e.set_input(text);
        }
    }));
}

/// 清空输入缓冲。
///
/// # Safety
/// 同 [`qj_engine_free`]。
#[unsafe(no_mangle)]
pub extern "C" fn qj_engine_clear(engine: *mut QjEngine) {
    let _ = catch_unwind(AssertUnwindSafe(|| unsafe {
        if let Some(e) = engine.as_ref() {
            e.clear();
        }
    }));
}

/// 查询候选，返回 JSON C 字符串（调用方用 [`qj_string_free`] 释放）；失败返回 null。
///
/// # Safety
/// 同 [`qj_engine_free`]。
#[unsafe(no_mangle)]
pub extern "C" fn qj_engine_query(engine: *mut QjEngine) -> *mut c_char {
    let result = catch_unwind(AssertUnwindSafe(|| unsafe {
        engine.as_ref().map(QjEngine::query)
    }));
    match result {
        Ok(Some(json)) => into_c_string(json),
        _ => std::ptr::null_mut(),
    }
}

/// 上屏第 `index` 个候选，返回上屏文本（调用方释放）；无候选返回 null。
///
/// # Safety
/// 同 [`qj_engine_free`]。
#[unsafe(no_mangle)]
pub extern "C" fn qj_engine_commit(engine: *mut QjEngine, index: usize) -> *mut c_char {
    let result = catch_unwind(AssertUnwindSafe(|| unsafe {
        engine.as_ref().and_then(|e| e.commit_index(index))
    }));
    match result {
        Ok(Some(text)) => into_c_string(text),
        _ => std::ptr::null_mut(),
    }
}

/// 原样上屏缓冲内容（英文直出/回车），返回文本（调用方释放）。
///
/// # Safety
/// 同 [`qj_engine_free`]。
#[unsafe(no_mangle)]
pub extern "C" fn qj_engine_commit_raw(engine: *mut QjEngine) -> *mut c_char {
    let result = catch_unwind(AssertUnwindSafe(|| unsafe {
        engine.as_ref().map(QjEngine::commit_raw)
    }));
    match result {
        Ok(Some(text)) => into_c_string(text),
        _ => std::ptr::null_mut(),
    }
}

/// 落盘学习数据。
///
/// # Safety
/// 同 [`qj_engine_free`]。
#[unsafe(no_mangle)]
pub extern "C" fn qj_engine_flush(engine: *mut QjEngine) {
    let _ = catch_unwind(AssertUnwindSafe(|| unsafe {
        if let Some(e) = engine.as_ref() {
            e.flush();
        }
    }));
}

/// 繁体输出开关（非 0 为繁体）。
///
/// # Safety
/// 同 [`qj_engine_free`]。
#[unsafe(no_mangle)]
pub extern "C" fn qj_engine_set_traditional(engine: *mut QjEngine, on: i32) {
    let _ = catch_unwind(AssertUnwindSafe(|| unsafe {
        if let Some(e) = engine.as_ref() {
            e.set_traditional(on != 0);
        }
    }));
}

/// 释放由本 crate 返回的字符串。
///
/// # Safety
/// `p` 必须是本 crate 返回的、尚未释放的字符串，或为 null。
#[unsafe(no_mangle)]
pub extern "C" fn qj_string_free(p: *mut c_char) {
    let _ = catch_unwind(AssertUnwindSafe(|| unsafe {
        if !p.is_null() {
            drop(CString::from_raw(p));
        }
    }));
}
