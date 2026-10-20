#!/usr/bin/env bash
# 下载青简产品数据包，把键盘扩展需要的资源放入 QJKeyboard/Resources。
#
# M0 内存策略：默认只打包主词库 dict.qj（mmap 只读）。
# 若要启用二元整句模型，设置环境变量 INCLUDE_LM=1 再跑本脚本（会额外打 lm.qj）。
# 神经模型（models/*.qjm）M0 不打包。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCES="$IOS_DIR/QJKeyboard/Resources"

REPO="qingjian-team/qingjian"
TAG="data-v7"
EXPECTED_SHA="e259f8bc2a5456c92484c5d4362ca56b3e46b3d2e1a0d463788091a039d79e40"
URL="https://github.com/$REPO/releases/download/$TAG/qingjian-data.tar.gz"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> 下载数据包 ${TAG}（约 137MB）"
curl -fL --retry 3 -o "$TMP/data.tar.gz" "$URL"

echo "==> 校验 SHA-256"
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL="$(sha256sum "$TMP/data.tar.gz" | cut -d' ' -f1)"
else
  ACTUAL="$(shasum -a 256 "$TMP/data.tar.gz" | cut -d' ' -f1)"
fi
if [[ "$ACTUAL" != "$EXPECTED_SHA" ]]; then
  echo "❌ 数据包校验失败：期望 ${EXPECTED_SHA}，实际 ${ACTUAL}" >&2
  exit 1
fi

echo "==> 解压"
mkdir -p "$TMP/x"
tar -xzf "$TMP/data.tar.gz" -C "$TMP/x"

mkdir -p "$RESOURCES"
# 兼容 tar 顶层为 data/ 或直接 generated/ 两种布局。
pick() {
  find "$TMP/x" -type f -name "$1" | head -1
}

DICT="$(pick dict.qj)"
if [[ -z "$DICT" ]]; then
  echo "❌ 数据包中未找到 dict.qj" >&2
  exit 1
fi
cp "$DICT" "$RESOURCES/dict.qj"
echo "✅ 已放置 dict.qj"

if [[ "${INCLUDE_LM:-0}" == "1" ]]; then
  LM="$(pick lm.qj)"
  if [[ -n "$LM" ]]; then
    cp "$LM" "$RESOURCES/lm.qj"
    echo "✅ 已放置 lm.qj"
  else
    echo "⚠️ 未找到 lm.qj，跳过"
  fi
fi

# 可选：英文译词表 / 英文候选词表（若数据包含，且体积可接受）。
for f in glossary-en.tsv english.tsv; do
  P="$(pick "$f")"
  if [[ -n "$P" ]]; then
    cp "$P" "$RESOURCES/$f"
    echo "✅ 已放置 $f"
  fi
done

echo "==> Resources 目录内容："
ls -lh "$RESOURCES"
echo "✅ 资源就绪"
