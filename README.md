# OrangeFox Device Tree for Xiaomi lmi (POCO F2 Pro / Redmi K30 Pro / Redmi K30 Pro Zoom Edition)

## Device specs
|     Item | Value |
|----------|-------|
SoC          | Snapdragon 865 (SM8250 / Kona)
CPU           | 8 cores (1 x Kryo 585 Prime (A77): 2.84 GHz 3 x Kryo 585 Gold (A77): 2.42 GHz 4 x Kryo 585 Silver (A55): 1.8 GHz) 
RAM           | 6/8/12GB LPDDR4X/LPDDR5
Storage    | 128/256/512 GB UFS 3.0/UFS 3.1
Battery    | Li-Po 4700mAh
Display    | 2400x1080 60Hz 6.67in OLED
Dimensions | 163.3x75.4x8.9mm
Kernel     | 4.19 
A/B        | A-only

## Build

### Clone & Sync Source (Android 16 / fox_16.0)
```
mkdir ~/fox_16.0
cd ~/fox_16.0
repo init --depth=1 -u https://gitlab.com/OrangeFox/Manifest.git -b fox_16.0
repo sync -c -j32 --force-sync --no-clone-bundle --no-tags
```
### Clone Device-tree
```
mkdir -p ~/fox_16.0/device/xiaomi
cd ~/fox_16.0/device/xiaomi
git clone -b fox_12.1 https://github.com/FreeAsCrazy/lmi-recovery1.git lmi
```
### BUILD!
```
cd ~/fox_16.0
source build/envsetup.sh
lunch twrp_lmi-bp2a-eng
mka recoveryimage -j$(($(nproc) * 2))
```

> A16 适配要点（GitHub Actions 工作流已自动处理）：
> - `PRODUCT_CHECK_PREBUILT_MAX_PAGE_SIZE := false`（4KB 页内核 + 4K 对齐预编译 ELF 豁免 16KB 检查）
> - `TARGET_RECOVERY_PIXEL_FORMAT` 去掉裸双引号（否则破坏 soong extra.variables JSON）
> - 删除设备树里硬编码的 `PLATFORM_VERSION`
> - `PRODUCT_SHIPPING_API_LEVEL := 36`；lunch 走三段式 `twrp_lmi-bp2a-eng`
> - 源码侧兜底 `AID_MEDIA_RW`、修 openaes 的 K&R 旧式 C 警告升级
