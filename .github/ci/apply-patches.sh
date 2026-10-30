#!/usr/bin/env bash
# A16 兼容补丁（固化在仓库文件里）
# 由工作流在同步源码、放入设备树后调用。
set -euo pipefail
: "${FOX_DIR:?FOX_DIR not set}"
cd "$FOX_DIR"
D=device/xiaomi/lmi
CI_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo "===== 一、设备树适配 A16 ====="

# 1) A16 对预编译 ELF 强制 16KB 页对齐检查。lmi 是 4KB 页内核，且 recovery/root 里
#    全是 4K 对齐的老 HIDL 二进制 —— 用检查器官方开关全局豁免
grep -q 'PRODUCT_CHECK_PREBUILT_MAX_PAGE_SIZE' "$D/device.mk" ||
  echo 'PRODUCT_CHECK_PREBUILT_MAX_PAGE_SIZE := false' >> "$D/device.mk"
grep -q 'PRODUCT_CHECK_PREBUILT_MAX_PAGE_SIZE := false' "$D/device.mk"

# 2) BoardConfig 里带裸双引号的值会破坏 soong 的 extra.variables JSON
#    （TARGET_RECOVERY_PIXEL_FORMAT 在 vendor/twrp 的 EXPORT_TO_SOONG 名单里）
sed -i 's/^\(TARGET_RECOVERY_PIXEL_FORMAT *:*= *\)"\(.*\)"$/\1\2/' "$D/BoardConfig.mk"
grep -q 'TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888' "$D/BoardConfig.mk"

# 3) 设备树来自旧基线，硬编码 PLATFORM_VERSION 会与 A16 的版本体系冲突 → 交给构建系统
sed -i -e '/^PLATFORM_VERSION := /d' -e '/^PLATFORM_VERSION_LAST_STABLE := /d' "$D/BoardConfig.mk"

# 4) 出货 API 对齐 A16
sed -i 's/^PRODUCT_SHIPPING_API_LEVEL := 29/PRODUCT_SHIPPING_API_LEVEL := 36/' "$D/device.mk"
grep -q 'PRODUCT_SHIPPING_API_LEVEL := 36' "$D/device.mk"

# 5) A16 的 lunch 走三段式；发布标识由 vendor/twrp/vars/aosp_target_release 指定（=bp2a）
grep -q 'twrp_lmi-bp2a-eng' "$D/AndroidProducts.mk" ||
  sed -i 's/twrp_lmi-eng/twrp_lmi-bp2a-eng/' "$D/AndroidProducts.mk"
grep -q 'twrp_lmi-bp2a-eng' "$D/AndroidProducts.mk"

# 6) 少编一个 toolbox（恢复模式已用 toybox），省时间与内存
if grep -q '^TW_USE_TOOLBOX := true' "$D/BoardConfig.mk"; then
  sed -i 's/^TW_USE_TOOLBOX := true/TW_USE_TOOLBOX := false/' "$D/BoardConfig.mk"
fi
grep '^TW_USE_TOOLBOX' "$D/BoardConfig.mk"

echo "===== 二、A16 源码侧修补 ====="

# 1) AID_MEDIA_RW 在 A16 里仍然是 1023（libcutils 私有头），但这些源文件没把它引进来，
#    会集体报“未声明标识符”错误 → 用等值定义兜底
patched=0
for f in $(grep -rl "AID_MEDIA_RW" bootable/recovery --include='*.cpp' --include='*.h' 2>/dev/null || true); do
  if ! grep -q '#define AID_MEDIA_RW' "$f"; then
    sed -i "1s|^|#ifndef AID_MEDIA_RW\n#define AID_MEDIA_RW 1023  /* 与 AOSP libcutils 私有头一致 */\n#endif\n\n|" "$f"
    patched=$((patched + 1))
  fi
done
echo "AID_MEDIA_RW 兜底完成：$patched 个文件"
grep -q '#define AID_MEDIA_RW 1023' bootable/recovery/partitionmanager.cpp

# 2) A16 的 clang 默认 -std=gnu23（soong cc/config/global.go: CStdVersion = "gnu23"），
#    而 C23 里 K&R 旧式函数定义已删除、`foo()` 变成「无参数」——
#    openaes 是 2008 年的 K&R 代码（rand.c:28 `void isaac(ctx)`、oaes_lib.c 调 `foo()`），
#    直接编不过。用构建系统的一等开关 LOCAL_C_STD 退回 gnu99（binary.mk:473-479），
#    比往 LOCAL_CFLAGS 里硬塞 -std= 可靠。
if [ -f bootable/recovery/openaes/Android.mk ]; then
  # 先把 `LOCAL_CFLAGS:=` 改成 `+=`，否则注入的 -Wno-* 会被这一行整体覆盖
  sed -i 's/^\(\t*\)LOCAL_CFLAGS:= /\1LOCAL_CFLAGS += /' bootable/recovery/openaes/Android.mk
  count=$(grep -c 'include \$(CLEAR_VARS)' bootable/recovery/openaes/Android.mk)
  [ "$count" -ge 3 ] || { echo "openaes/Android.mk 段数异常: $count" >&2; exit 1; }
  tmp=$(mktemp)
  awk '{print} /include \$\(CLEAR_VARS\)/ {print "	LOCAL_C_STD := gnu99"; print "	LOCAL_CFLAGS += -Wno-deprecated-non-prototype -Wno-error=implicit-function-declaration -Wno-error=int-conversion -Wno-error=incompatible-function-pointer-types"}' bootable/recovery/openaes/Android.mk > "$tmp"
  mv "$tmp" bootable/recovery/openaes/Android.mk
  grep -q 'LOCAL_C_STD := gnu99' bootable/recovery/openaes/Android.mk
  grep -q 'Wno-deprecated-non-prototype' bootable/recovery/openaes/Android.mk
  grep -q 'LOCAL_CFLAGS += -g -c -W' bootable/recovery/openaes/Android.mk
fi

# 2b) recovery 目录下还有十来个 2010 年前的老 C 模块（libtar/dosfstools/libblkid/
#     pigz/flashutils/mtdutils/attr/...），和 openaes 一样都是 K&R 时代的产物。
#     光修 openaes 等于打地鼠，这里给整个目录一次到位：
#       - 默认 C 标准退回 gnu99（C23 删掉了 K&R 定义、`foo()` 变 (void)）
#       - 关掉会因全局 -Werror 而致命的旧代码警告
#     警告只挂到 conlyflags（.c 专用）：挂到 cflags 会落到 C++ 文件上，
#     而 `-Wno-deprecated-non-prototype` 对 clang++ 是未知告警选项，-Werror 下反成新错误。
#     全局的 -std=/-Werror 在编译命令里排在模块 flags 之前
#     （definitions.mk:1652-1661 → $(GLOBAL...) 在 $(PRIVATE_CFLAGS/CONLYFLAGS) 前面），
#     所以这里后加的会覆盖生效。

if ! grep -q 'my_conlyflags += -Wno-deprecated-non-prototype' build/make/core/binary.mk; then
  count=$(grep -c 'my_c_std_version := \$(LOCAL_C_STD)' build/make/core/binary.mk)
  [ "$count" = 1 ] || { echo "binary.mk C_STD 块数量异常: $count" >&2; exit 1; }
  tmp=$(mktemp)
  awk '
    {print}
    /^[[:space:]]*my_c_std_version := \$\(LOCAL_C_STD\)$/ {marked=1}
    marked && /^[[:space:]]*endif$/ {
      print ""
      print "# OrangeFox: recovery 下多为老式 C 代码，A16 默认 gnu23 编不过 -> 退回 gnu99"
      print "ifneq (,$(filter bootable/recovery bootable/recovery/%,$(LOCAL_PATH)))"
      print "  ifeq ($(LOCAL_C_STD),)"
      print "    my_c_std_version := gnu99"
      print "  endif"
      print "  my_conlyflags += -Wno-deprecated-non-prototype -Wno-error=implicit-function-declaration -Wno-error=int-conversion -Wno-error=incompatible-function-pointer-types"
      print "endif"
      marked=0
    }
  ' build/make/core/binary.mk > "$tmp"
  mv "$tmp" build/make/core/binary.mk
fi
grep -q 'bootable/recovery bootable/recovery/%' build/make/core/binary.mk
grep -q 'my_conlyflags += -Wno-deprecated-non-prototype' build/make/core/binary.mk

# 3) 清单已移除 test/vts*，但 build/make 的 test-suite 展开仍引用 vts/tvts
if grep -q 'device-tests vts tvts art-host-tests' build/make/core/main.mk; then
  sed -i 's/device-tests vts tvts art-host-tests/device-tests art-host-tests/' build/make/core/main.mk
  grep -q 'device-tests art-host-tests' build/make/core/main.mk

  # 4) libvts_vintf_test_common 被 assemble_vintf 硬依赖，但定义在被移除的
  #    test/vts-testcase/hal 里 → 只补这一模块的 3 个小文件，不整仓恢复
  VLIB=test/vts-testcase/hal/treble/vintf/libvts_vintf_test_common
  if [ ! -f "$VLIB/Android.bp" ]; then
    VURL=https://android.googlesource.com/platform/test/vts-testcase/hal/+/master/treble/vintf/libvts_vintf_test_common
    mkdir -p "$VLIB/include/libvts_vintf_test_common"
    curl -fsSL --retry 3 "$VURL/Android.bp?format=TEXT" | base64 -d > "$VLIB/Android.bp"
    curl -fsSL --retry 3 "$VURL/common.cpp?format=TEXT" | base64 -d > "$VLIB/common.cpp"
    curl -fsSL --retry 3 "$VURL/include/libvts_vintf_test_common/common.h?format=TEXT" | base64 -d > "$VLIB/include/libvts_vintf_test_common/common.h"
  fi
  grep -q 'name: "libvts_vintf_test_common"' "$VLIB/Android.bp"
  [ -s "$VLIB/common.cpp" ]
  echo "libvts_vintf_test_common 已补齐"
else
  echo "main.mk 无需 vts/tvts 补丁（清单已处理）"
fi

echo "===== 三、核对结果 ====="
grep -n 'PRODUCT_CHECK_PREBUILT_MAX_PAGE_SIZE\|PRODUCT_SHIPPING_API_LEVEL' "$D/device.mk"
grep -n 'TARGET_RECOVERY_PIXEL_FORMAT\|TW_USE_TOOLBOX\|^PLATFORM_VERSION' "$D/BoardConfig.mk"
grep -n 'LUNCH' "$D/AndroidProducts.mk"
echo "--- 架构：lmi 为 64 位纯设备，必须没有 32 位第二架构 ---"
grep -n 'TARGET_ARCH :=\|TARGET_2ND_ARCH\|SUPPORTS_32_BIT\|SUPPORTS_64_BIT' "$D/BoardConfig.mk"
! grep -q '^TARGET_2ND_ARCH' "$D/BoardConfig.mk"
grep -q '^TARGET_SUPPORTS_32_BIT_APPS := false' "$D/BoardConfig.mk"
df -h /

echo "===== 四、A16 vold 解密修补 ====="
python3 "$CI_DIR/patches/patch-vold-a16.py" "$FOX_DIR"

echo "===== 五、Keystore2 watchdog ====="
bash "$CI_DIR/patches/patch-keystore2-watchdog.sh"

echo "===== 六、pigz 僵尸修复 ====="
python3 "$CI_DIR/patches/patch-pigz-zombie.py" "$FOX_DIR"

echo "===== 七、中文翻译 ====="
bash "$CI_DIR/patches/patch-ui-translations.sh"
