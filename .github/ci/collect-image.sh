#!/usr/bin/env bash
# 收集 recovery.img，按 OrangeFox-<版本>-<分支>-lmi-<时间戳>.img 命名并校验。
set -euo pipefail

: "${FOX_DIR:?FOX_DIR not set}"
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE not set}"

rm -rf "$GITHUB_WORKSPACE/dist"
mkdir -p "$GITHUB_WORKSPACE/dist"
OUT="$FOX_DIR/out/target/product/lmi"
OUT_IMG="$OUT/recovery.img"

if [ ! -f "$OUT_IMG" ]; then
  echo "错误：没有找到 recovery.img"
  exit 1
fi
echo "镜像源文件: $OUT_IMG"

FOX_VER=""
for img in "$OUT"/OrangeFox-*.img; do
  [ -f "$img" ] || continue
  FOX_VER=$(basename "$img" | sed -nE 's/^OrangeFox-([^-]+)-.*/\1/p')
  [ -n "$FOX_VER" ] && break
done
if [ -z "$FOX_VER" ]; then
  FOX_VER=$(grep -oP '(FOX_MAINTAINER_PATCH_VERSION|FOX_VERSION)\s*=\s*"\K[^"]+' \
            "$FOX_DIR/device/xiaomi/lmi/vendorsetup.sh" 2>/dev/null | head -1) || true
fi
[ -n "$FOX_VER" ] || FOX_VER="R12.0"
FOX_VER=$(printf '%s' "$FOX_VER" | sed -E 's/[^A-Za-z0-9._-]+/-/g')

FOX_BRANCH_TAG=${FOX_BRANCH:-fox_16.0}
FOX_BRANCH_TAG=$(printf '%s' "$FOX_BRANCH_TAG" | sed -E 's/^fox_/fox/; s/[^A-Za-z0-9._-]+/-/g')

TS=$(date +%Y%m%d%H%M%S)
BASE="OrangeFox-${FOX_VER}-${FOX_BRANCH_TAG}-lmi-${TS}"
echo "PRODUCT_BASE=${BASE}" >> "$GITHUB_ENV"
IMG_SRC="$GITHUB_WORKSPACE/dist/${BASE}.img"
cp -v "$OUT_IMG" "$IMG_SRC"
echo "产物: $IMG_SRC"

if [ ! -s "$IMG_SRC" ]; then
  echo "错误：生成的 recovery.img 为空"
  exit 1
fi

echo "=== 镜像产物 ==="
ls -lh "$GITHUB_WORKSPACE/dist/"
file "$GITHUB_WORKSPACE"/dist/* 2>/dev/null || true

echo "=== 镜像校验 ==="
python3 "$GITHUB_WORKSPACE/.github/ci/verify-recovery.py" "$IMG_SRC"
