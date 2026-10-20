//
//  qingjian_ios.h
//  青简 iOS Rust 内核的 C ABI 头文件。
//
//  作为键盘扩展 target 的 Objective-C bridging header，Swift 即可直接调用这些函数。
//

#ifndef QINGJIAN_IOS_H
#define QINGJIAN_IOS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 不透明引擎句柄。
typedef struct QjEngine QjEngine;

/// 创建引擎，失败返回 NULL。
/// resources_dir：bundle 内只读资源目录；writable_dir：扩展私有可写目录；lang_code：译词语言代码。
QjEngine *qj_engine_new(const char *resources_dir, const char *writable_dir, const char *lang_code);

/// 销毁引擎（NULL 安全）。
void qj_engine_free(QjEngine *engine);

/// 整段替换当前拼音串。
void qj_engine_set_input(QjEngine *engine, const char *input);

/// 清空输入缓冲。
void qj_engine_clear(QjEngine *engine);

/// 查询候选，返回 JSON 字符串（调用方用 qj_string_free 释放），失败返回 NULL。
char *qj_engine_query(QjEngine *engine);

/// 上屏第 index 个候选（从 0 起），返回上屏文本（调用方释放），无候选返回 NULL。
char *qj_engine_commit(QjEngine *engine, size_t index);

/// 原样上屏缓冲内容（英文直出 / 回车），返回文本（调用方释放）。
char *qj_engine_commit_raw(QjEngine *engine);

/// 落盘学习数据。
void qj_engine_flush(QjEngine *engine);

/// 繁体输出开关（非 0 为繁体）。
void qj_engine_set_traditional(QjEngine *engine, int on);

/// 释放本库返回的字符串（NULL 安全）。
void qj_string_free(char *p);

#ifdef __cplusplus
}
#endif

#endif /* QINGJIAN_IOS_H */
