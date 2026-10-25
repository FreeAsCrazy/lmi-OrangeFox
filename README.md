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
> - `bootable/recovery` 下所有 C 模块退回 `-std=gnu99`（A16 clang 默认 C23，K&R 定义与 `foo()` 语义都变了）

## 刷入（lmi 为 A-only 设备，有独立 recovery 分区）

产物有两个等价镜像：`recovery.img` 与 `OrangeFox-R12.0-Unofficial-lmi.img`（md5 相同），
推荐直接用签名 zip 在现有 recovery 里刷，或用 fastboot 刷 img。

### 方式一：fastboot（推荐，不依赖当前 recovery）
```
fastboot flash recovery OrangeFox-R12.0-Unofficial-lmi.img
fastboot reboot recovery          # 或关机后 电源+音量上 进 recovery
```

### 方式二：在已有 TWRP/OrangeFox 里刷 zip
把 `OrangeFox-R12.0-Unofficial-lmi.zip` 放进手机存储 → Install → 选中 zip → 滑动刷入。
（zip 是 SignApk testkey 签名，OrangeFox/TWRP 默认不校验签名，可正常刷入。）

### 刷完请自检这几项
| 检查项 | 预期 |
|---|---|
| 语言 | 默认简体中文（`TW_DEFAULT_LANGUAGE="zh_CN"`） |
| 版本/维护者 | About 页显示 `Unofficial`，维护者 `opencode` |
| 挂载 | `/system`、`/vendor`、`/product` 能挂上（A16 的 system 是 erofs） |
| 解密 | 若 ROM 的 `/data` 是 FBE 加密，输入锁屏密码应能解开 |
| 备份 | 备份 boot / dtbo 正常；Test backup 模式可试跑 |

> 注意：`/external_sd` 挂载项在本设备树里被上游删掉了，插 MicroSD 卡不会出现在 recovery 的挂载列表里。

