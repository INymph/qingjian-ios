# 青简 iOS 移植（M0）

青简平台无关 Rust 内核的 iOS 键盘扩展，仅用于个人研究与自包含侧载（TrollStore 永久安装）。

## 目录

- `qingjian-ios/`：Rust 桥接 crate，`crate-type = ["staticlib"]`，对 Swift 暴露 C ABI；
- `QJKeyboard/`：XcodeGen 工程
  - `App/`：宿主 App（承载扩展 + 启用引导）；
  - `Keyboard/`：SwiftUI 键盘扩展、C bridging header、Rust 桥接封装；
  - `Resources/`：词库资源（构建时填充，不进版本库）；
  - `Frameworks/`：Rust 静态库 xcframework（构建产物，不进版本库）；
- `scripts/`：交叉编译、取资源、打包 IPA 的脚本。

## 云端构建（推荐，无需 Mac）

推送本目录后，GitHub Actions 工作流 `Build iOS Keyboard (IPA)` 会自动执行，
产物为未签名、已 ad-hoc fakesign 的 `QJKeyboard-unsigned.ipa`，用 TrollStore 安装即可永久使用。

## 本地构建（需要 macOS）

```bash
bash apps/ios/scripts/build-xcframework.sh   # Rust -> xcframework
bash apps/ios/scripts/fetch-resources.sh     # 下载词库（INCLUDE_LM=1 可附带 lm.qj）
bash apps/ios/scripts/pack-ipa.sh            # 生成工程、构建、打包 IPA
```

## M0 范围

全拼输入、候选选择与上屏、英文直出、中英切换、退格/空格/回车、自包含主词库、
个人学习数据落盘。双拼/符号键盘/译词/emoji/神经整句在后续里程碑。
