#!/usr/bin/env bash
# 生成 Xcode 工程、未签名构建、对二进制做 ad-hoc fakesign、打包 TrollStore 可安装的 IPA。
#
# 用法：
#   apps/ios/scripts/pack-ipa.sh [输出目录]
# 前置：build-xcframework.sh 与 fetch-resources.sh 已执行（CI 工作流会按顺序调用）。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJ_DIR="$IOS_DIR/QJKeyboard"
OUT_DIR="${1:-$IOS_DIR/build-ipa}"
mkdir -p "$OUT_DIR"
# 转绝对路径：脚本随后会 cd 到工程目录，避免相对路径解析错位。
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

echo "==> 检查 / 安装 XcodeGen 与 ldid"
command -v xcodegen >/dev/null 2>&1 || brew install xcodegen
command -v ldid >/dev/null 2>&1 || brew install ldid

echo "==> 确认 xcframework 已存在"
if [[ ! -d "$PROJ_DIR/Frameworks/qingjian_ios.xcframework" ]]; then
  echo "❌ 缺少 Frameworks/qingjian_ios.xcframework，请先运行 build-xcframework.sh" >&2
  exit 1
fi
echo "==> 确认词库已存在"
if [[ ! -f "$PROJ_DIR/Resources/dict.qj" ]]; then
  echo "❌ 缺少 Resources/dict.qj，请先运行 fetch-resources.sh" >&2
  exit 1
fi

cd "$PROJ_DIR"

echo "==> 生成 Xcode 工程"
xcodegen generate

echo "==> 未签名构建（真机，Release）"
rm -rf build
xcodebuild \
  -project QJKeyboard.xcodeproj \
  -scheme QJApp \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_STYLE="" \
  build

APP_PATH="build/Build/Products/Release-iphoneos/QJApp.app"
APPEX_PATH="$APP_PATH/PlugIns/QJKeyboard.appex"
if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ 构建产物缺失：$APP_PATH" >&2
  exit 1
fi
if [[ ! -d "$APPEX_PATH" ]]; then
  echo "❌ 键盘扩展未嵌入：$APPEX_PATH（检查 QJApp 对 QJKeyboard 的 target 依赖）" >&2
  exit 1
fi

echo "==> 组装 Payload 并 ad-hoc fakesign（供 TrollStore 永久安装）"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/Payload"
cp -R "$APP_PATH" "$WORK/Payload/"

ldid -S "$WORK/Payload/QJApp.app/QJApp"
ldid -S "$WORK/Payload/QJApp.app/PlugIns/QJKeyboard.appex/QJKeyboard"

IPA="$OUT_DIR/QJKeyboard-unsigned.ipa"
rm -f "$IPA"
( cd "$WORK" && zip -qr "$IPA" Payload )

echo "✅ IPA 已生成：$IPA"
ls -lh "$IPA"
echo "==> Payload 结构（确认含键盘扩展）："
( cd "$WORK" && find Payload -maxdepth 3 -type d | sort )
