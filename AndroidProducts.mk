#
# Copyright (C) 2022 Team Win Recovery Project
#
# SPDX-License-Identifier: Apache-2.0
#

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/twrp_lmi.mk

# 默认暴露 eng 变体；16.0 的 bp2a 变体由 .github/ci/patch-a16.sh
# 在构建时按版本追加/替换，不能写死在这里。
COMMON_LUNCH_CHOICES := \
    twrp_lmi-user \
    twrp_lmi-userdebug \
    twrp_lmi-eng
