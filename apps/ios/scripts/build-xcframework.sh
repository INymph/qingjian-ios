#!/usr/bin/env bash
# 编译 Rust 内核为 iOS 真机静态库，并打包成 xcframework 供 XcodeGen 工程链接。
# TrollStore 侧载只需真机 arm64，因此只产出 aarch64-apple-ios 一个 slice。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$IOS_DIR/../.." && pwd)"
TARGET="aarch64-apple-ios"

cd "$REPO_ROOT"

echo "==> 安装 Rust 目标：$TARGET"
rustup target add "$TARGET"

echo "==> 编译 release staticlib"
cargo build --release --target "$TARGET" -p qingjian-ios

LIB="$REPO_ROOT/target/$TARGET/release/libqingjian_ios.a"
if [[ ! -f "$LIB" ]]; then
  echo "❌ 未找到静态库：$LIB" >&2
  exit 1
fi

HEADER_SRC="$IOS_DIR/QJKeyboard/Keyboard/qingjian_ios.h"
HEADER_DIR="$(mktemp -d)"
cp "$HEADER_SRC" "$HEADER_DIR/qingjian_ios.h"

OUT_DIR="$IOS_DIR/QJKeyboard/Frameworks"
OUT="$OUT_DIR/qingjian_ios.xcframework"
rm -rf "$OUT"
mkdir -p "$OUT_DIR"

echo "==> 创建 XCFramework（真机 slice）"
xcodebuild -create-xcframework \
  -library "$LIB" -headers "$HEADER_DIR" \
  -output "$OUT"

echo "✅ 已生成：$OUT"
