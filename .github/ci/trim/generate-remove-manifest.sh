#!/usr/bin/env bash
# 根据 repo manifest 和裁剪清单生成 .repo/local_manifests/remove.xml。
#
# 用法：
#   generate-remove-manifest.sh MANIFEST_XML TRIM_LIST OUTPUT_XML [REPLACES_XML]
#
# 参数：
#   MANIFEST_XML  repo manifest 生成的完整清单
#   TRIM_LIST     裁剪清单，一行一个项目路径，支持 # 注释和空行
#   OUTPUT_XML    输出的 local manifest
#   REPLACES_XML  可选的替换片段，追加到生成的 remove.xml 中
set -euo pipefail

MANIFEST_XML=${1:?用法: $0 MANIFEST_XML TRIM_LIST OUTPUT_XML [REPLACES_XML]}
TRIM_LIST=${2:?用法: $0 MANIFEST_XML TRIM_LIST OUTPUT_XML [REPLACES_XML]}
OUTPUT_XML=${3:?用法: $0 MANIFEST_XML TRIM_LIST OUTPUT_XML [REPLACES_XML]}
REPLACES_XML=${4:-}

for f in "$MANIFEST_XML" "$TRIM_LIST"; do
  if [ ! -s "$f" ]; then
    echo "错误：文件不存在或为空：$f" >&2
    exit 1
  fi
done
if [ -n "$REPLACES_XML" ] && [ ! -s "$REPLACES_XML" ]; then
  echo "错误：替换片段不存在或为空：$REPLACES_XML" >&2
  exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
MANIFEST_PATHS="$TMP_DIR/manifest-paths.txt"
REMOVE_LIST="$TMP_DIR/remove-projects.txt"

grep -oP '<project\b[^>]*\bpath="\K[^"]+' "$MANIFEST_XML" \
  | sort -u > "$MANIFEST_PATHS"

declare -A TRIM_SET=()
while IFS= read -r p; do
  p="${p%%#*}"
  p="${p#"${p%%[![:space:]]*}"}"
  p="${p%"${p##*[![:space:]]}"}"
  [ -z "$p" ] && continue
  TRIM_SET["$p"]=1
done < "$TRIM_LIST"

is_removed() {
  local p=$1
  [[ -n ${TRIM_SET[$p]+x} ]] && return 0
  case "$p" in
    cts|cts/*|sdk|sdk/*|developers/*|device/generic/*|device/google/*|device/amlogic/*|device/asus/*|device/brcm/*|device/linaro/*|device/ti/*|device/sample/*|kernel/prebuilts|kernel/prebuilts/*|prebuilts/android-emulator|prebuilts/android-emulator/*|prebuilts/qemu-kernel|prebuilts/qemu-kernel/*) return 0 ;;
    test/dittosuite|test/robolectric-extensions|test/mlts/benchmark|test/mlts/models|test/cts-root|test/mts|test/suite_harness|test/vts|test/catbox|test/vts-testcase/hal|test/vts-testcase/kernel|test/vts-testcase/nbu|test/vts-testcase/performance|test/vts-testcase/security|test/vts-testcase/vndk) return 0 ;;
  esac
  return 1
}

while IFS= read -r p; do
  is_removed "$p" && printf '%s\n' "$p"
done < "$MANIFEST_PATHS" > "$REMOVE_LIST"

mkdir -p "$(dirname "$OUTPUT_XML")"
{
  printf '<manifest>\n'
  sed 's/.*/  <remove-project path="&" \/>/' "$REMOVE_LIST"
  if [ -n "$REPLACES_XML" ]; then
    cat "$REPLACES_XML"
  fi
  printf '</manifest>\n'
} > "$OUTPUT_XML"

trim_count=$(grep -vcE '^[[:space:]]*(#|$)' "$TRIM_LIST" || true)
remove_count=$(wc -l < "$REMOVE_LIST")
echo "== 自动剔除 ${remove_count} 个项目（前缀规则 + 裁剪表 ${trim_count} 条）=="
cat "$OUTPUT_XML"
