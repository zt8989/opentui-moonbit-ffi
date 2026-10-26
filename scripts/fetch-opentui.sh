#!/usr/bin/env bash
# 获取并构建 OpenTUI 原生库，产物放入 vendor/dist/<target>/。
#
# 用法：
#   scripts/fetch-opentui.sh
# 环境变量：
#   OPENTUI_SRC   指向已有的 opentui 源码目录（跳过克隆）
#   OPENTUI_REF   要检出的 tag/commit（默认浅克隆默认分支）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor"
SRC="${OPENTUI_SRC:-$VENDOR/opentui}"
REF="${OPENTUI_REF:-}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "缺少依赖: $1 （$2）" >&2
    exit 1
  }
}

need git "克隆 opentui 仓库"
need bun "安装依赖与运行构建脚本"

ZIG="${ZIG:-zig}"
if ! command -v "$ZIG" >/dev/null 2>&1; then
  echo "缺少依赖: zig 0.16.x（macOS 可用 'brew install zig@0.16'，并确保 zig 在 PATH 中）" >&2
  exit 1
fi
ZIG_VERSION="$("$ZIG" version)"
case "$ZIG_VERSION" in
  0.16.*) ;;
  *) echo "zig 版本必须是 0.16.x，当前为 $ZIG_VERSION（opentui 的 build.zig 锁定该版本）" >&2; exit 1 ;;
esac

# 主机 triple → opentui 的 lib/ 目录名（见其 build.zig 的 target 列表）
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) TARGET="aarch64-macos" ;;
  Darwin-x86_64) TARGET="x86_64-macos" ;;
  Linux-x86_64) TARGET="x86_64-linux" ;;
  Linux-aarch64) TARGET="aarch64-linux" ;;
  *) echo "暂不支持的主机: $(uname -s)-$(uname -m)，可手动构建后把 lib/<target> 放入 vendor/dist/" >&2; exit 1 ;;
esac

if [ ! -d "$SRC" ]; then
  mkdir -p "$VENDOR"
  echo "==> 克隆 opentui 到 $SRC"
  git clone --depth 1 ${REF:+--branch "$REF"} https://github.com/anomalyco/opentui.git "$SRC"
fi

echo "==> 安装依赖"
(cd "$SRC" && bun install)

echo "==> 构建 native（zig $ZIG_VERSION，ReleaseFast）"
(cd "$SRC/packages/native" && "$ZIG" build -Doptimize=ReleaseFast)

mkdir -p "$VENDOR/dist/$TARGET"
cp "$SRC/packages/native/lib/$TARGET/opentui.h" "$VENDOR/dist/$TARGET/"
cp "$SRC/packages/native/lib/$TARGET/libopentui.dylib" "$VENDOR/dist/$TARGET/" 2>/dev/null || true
cp "$SRC/packages/native/lib/$TARGET/libopentui.so" "$VENDOR/dist/$TARGET/" 2>/dev/null || true
cp "$SRC/packages/native/lib/$TARGET/libopentui.a" "$VENDOR/dist/$TARGET/" 2>/dev/null || true

echo "==> 完成：vendor/dist/$TARGET/"
ls -la "$VENDOR/dist/$TARGET/"
