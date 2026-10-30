#!/usr/bin/env bash
# 配置 lunch、ccache 并编译 recoveryimage，只生成 recovery.img。
set -o pipefail

: "${FOX_DIR:?FOX_DIR not set}"
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE not set}"
: "${BUILD_TARGET:?BUILD_TARGET not set}"
BUILD_JOBS=${BUILD_JOBS:-9}

# 不能启用 -u：AOSP build/envsetup.sh 会引用未定义的 TOP。
cd "$FOX_DIR" || exit 1

# 每 30 秒记录内存和 RSS 最高的进程，便于排查 OOM。
(
  while true; do
    echo "[$(date +%H:%M:%S)] $(free -h | awk '/^Mem:/{print "mem_used="$3" mem_avail="$4} /^Swap:/{print "swap_used="$3}')"
    ps -eo rss,comm --sort=-rss | head -6 | tail -5 \
      | awk '{printf "  rss=%dMB %s\n", $1/1024, $2}'
    sleep 30
  done
) &
WATCHDOG=$!
trap 'kill "$WATCHDOG" 2>/dev/null || true' EXIT

free -h
df -h /

# 兜底 OrangeFox envsetup 的返回值，以 lunch 是否可用判断真实成败。
if grep -q '^[[:space:]]*\[ -s \$FOX_MANIFEST_ROOT' build/make/envsetup.sh; then
  sed -i '/^[[:space:]]*\[ -s \$FOX_MANIFEST_ROOT/ s|$|; true|' build/make/envsetup.sh
  echo "已给 orangefox_envsetup 末行兜底:"
  grep -n '\[ -s \$FOX_MANIFEST_ROOT' build/make/envsetup.sh
fi

ENV_RC=0
source build/envsetup.sh || ENV_RC=$?
if ! command -v lunch >/dev/null 2>&1; then
  echo "!!! envsetup 返回 $ENV_RC 且 lunch 未定义，抓定位信息"
  bash -e -x -c 'source build/envsetup.sh' 2>&1 | tail -40 || true
  exit 1
fi
echo "envsetup 返回码: $ENV_RC（lunch 可用，继续）"

export SKIP_ABI_CHECKS=true
export FOX_BUGGED_AOSP_ARB_WORKAROUND="1588606644"
export FOX_RECOVERY_SYSTEM_PARTITION="/dev/block/mapper/system"
export FOX_RECOVERY_VENDOR_PARTITION="/dev/block/mapper/vendor"

lunch "$BUILD_TARGET" \
  || lunch twrp_lmi-ap3a-eng \
  || lunch twrp_lmi-ap2a-eng \
  || { echo "!!! lunch 失败: $BUILD_TARGET"; exit 1; }

# lunch 会 source vendorsetup.sh，所以必须在之后覆盖。
export FOX_DISABLE_UPDATEZIP=1
echo "FOX_DISABLE_UPDATEZIP=$FOX_DISABLE_UPDATEZIP（1=不生成卡刷 ZIP）"

export USE_CCACHE=1
export CCACHE_DIR="$HOME/.ccache"
export CCACHE_EXEC="$(command -v ccache || true)"
if [ -n "$CCACHE_EXEC" ]; then
  ccache -M 6G
  ccache -o compression=true
  ccache -o sloppiness=time_macros,include_file_mtime,file_macro
  ccache -o compiler_check=content
  echo "--- 本次恢复到的 ccache 现状（0 表示未命中）---"
  ccache -s -v | head -20 || true
  ccache -z
else
  echo "!!! 没找到 ccache，本轮不会有编译缓存"
fi

if command -v mka >/dev/null 2>&1; then
  BUILD_CMD=mka
else
  BUILD_CMD=m
fi
echo "使用编译命令: $BUILD_CMD recoveryimage -j$BUILD_JOBS"
BUILD_START=$(date +%s)
"$BUILD_CMD" recoveryimage -j"$BUILD_JOBS" 2>&1 | tee "$GITHUB_WORKSPACE/build.log"
RC=${PIPESTATUS[0]}
if [ -n "$CCACHE_EXEC" ]; then ccache -s || true; fi
ninja_total=$(grep -m1 -oP '/\d+\]' "$GITHUB_WORKSPACE/build.log" 2>/dev/null || true)
echo "=== 编译耗时：$(( ($(date +%s) - BUILD_START) / 60 )) 分钟 ==="
echo "=== ninja 目标总数：${ninja_total:-unknown} ==="

if [ "$RC" -ne 0 ]; then
  echo "===== 编译失败（exit=$RC），日志最后 80 行 ====="
  tail -80 "$GITHUB_WORKSPACE/build.log" || true
  echo "===== soong extra.variables 前 45 行 ====="
  sed -n '1,45p' out/soong/soong.twrp_lmi.extra.variables 2>&1 || true
  exit "$RC"
fi
