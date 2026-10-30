#!/usr/bin/env bash
# 初始化 OrangeFox/AOSP 清单，生成裁剪 manifest 并同步源码。
set -euo pipefail

: "${FOX_DIR:?FOX_DIR not set}"
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE not set}"
: "${FOX_MANIFEST:?FOX_MANIFEST not set}"
: "${FOX_BRANCH:?FOX_BRANCH not set}"
SYNC_JOBS=${SYNC_JOBS:-64}

SYNC_START=$(date +%s)
mkdir -p "$FOX_DIR"
cd "$FOX_DIR"

git config --global core.fsync none
git config --global checkout.workers 8
git config --global core.preloadIndex true
git config --global feature.manyFiles true

echo "=== repo init（完整清单 + 浅克隆）==="
T_INIT0=$(date +%s)
repo init --depth=1 -u "$FOX_MANIFEST" -b "$FOX_BRANCH"
T_INIT1=$(date +%s)

# 已验证不可裁剪：
# packages/modules/{adb,common,Gki,DnsResolver}
# prebuilts/{build-tools,clang/host/linux-x86,jdk/jdk8,rust}
# external/{llvm,perfetto,rappor,googletest,rust/android-crates-io,rust/cxx}
# frameworks/opt/telephony, tools/tradefederation/core
TRIM_LIST="$GITHUB_WORKSPACE/.github/ci/trim/16.0.txt"
TRIM_REPLACES="$GITHUB_WORKSPACE/.github/ci/trim/16.0.replaces.xml"
repo manifest -o "$GITHUB_WORKSPACE/manifest-resolved.xml"
bash "$GITHUB_WORKSPACE/.github/ci/trim/generate-remove-manifest.sh" \
  "$GITHUB_WORKSPACE/manifest-resolved.xml" \
  "$TRIM_LIST" \
  ".repo/local_manifests/remove.xml" \
  "$TRIM_REPLACES"

echo "=== repo sync ==="
T_SYNC0=$(date +%s)
success=false
for attempt in {1..5}; do
  if repo sync -c -j"$SYNC_JOBS" --optimized-fetch --no-clone-bundle --no-tags --retry-fetches=5; then
    success=true
    break
  fi
  echo "=== 第 $attempt 次 repo sync 失败，20 秒后重试 ==="
  sleep 20
done
[ "$success" = true ]
T_SYNC1=$(date +%s)

# .repo 和 GKI 预编译内核不参与 recovery 构建。
rm -rf .repo kernel/prebuilts
T_END=$(date +%s)

echo "=== 分段耗时：init=$((T_INIT1 - T_INIT0))s sync=$((T_SYNC1 - T_SYNC0))s cleanup=$((T_END - T_SYNC1))s ==="
test -f build/envsetup.sh
test -d vendor/twrp
test -d bootable/recovery
echo "=== 瘦身后磁盘 ==="
df -h /
echo "=== 同步总耗时：$(( $(date +%s) - SYNC_START )) 秒 ==="
