# 键盘扩展资源目录

本目录在构建时由 CI 脚本 `apps/ios/scripts/fetch-resources.sh` 填充：

- `dict.qj`：主词库（必需，mmap 只读）；
- `lm.qj`：二元整句语言模型（可选，体积/内存受限可移除）；
- `glossary-en.tsv` / `english.tsv`：英文译词与英文候选（可选）。

目录以 XcodeGen 的蓝色文件夹引用（`type: folder`）打包，构建后位于
`QJKeyboard.appex/Resources/`，Rust 端据此定位 `dict.qj`。

本地手动构建时，请先运行 `fetch-resources.sh` 再生成 Xcode 工程。
