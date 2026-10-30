#
#	此文件是OrangeFox恢复项目的一部分
# 	Copyright (C) 2021 The OrangeFox Recovery Project
#
#	OrangeFox是自由软件：您可以重新分发和/或修改它
#	前提是遵守由自由软件基金会发布的GNU通用公共许可证，
#	无论是许可证的第3版，还是（根据您的选择）任何后续版本。
#
#	OrangeFox的发布基于其可能有用这一前提，
#	但**不提供任何担保**；甚至不包含对**适销性**或**特定用途适用性**的默示担保。
#	详情请参阅GNU通用公共许可证。
#
# 	本软件根据GPL第3版或任何后续版本发布。
#	参见<http://www.gnu.org/licenses/>。
#
# 	如果您使用此脚本或其任何部分，请保留此声明
#
# 本文件集中放置 lmi 的 OrangeFox 编译配置。
# 0/1 开关均在行尾注明含义；路径、字符串、数值类配置不按 0/1 开关处理。
#
# 设备代号，指定当前构建的目标设备
FDEVICE="lmi"
#set -o xtrace

# 设备识别函数，检查当前构建环境是否针对指定设备
fox_get_target_device() {
   local chkdev
   chkdev=$(echo "$BASH_SOURCE" | grep -w "$FDEVICE")
   if [ -n "$chkdev" ]; then
      FOX_BUILD_DEVICE="$FDEVICE"
   else
      chkdev=$(set | grep BASH_ARGV | grep -w "$FDEVICE")
      [ -n "$chkdev" ] && FOX_BUILD_DEVICE="$FDEVICE"
   fi
}

if [ -z "$1" ] && [ -z "$FOX_BUILD_DEVICE" ]; then
   fox_get_target_device
fi

if [ "$1" = "$FDEVICE" ] || [ "$FOX_BUILD_DEVICE" = "$FDEVICE" ]; then

    # ===== 基础环境 =====
    export TW_DEFAULT_LANGUAGE="zh_CN"           # 默认语言：中文
    export LC_ALL="C"                            # 统一字符编码，避免中文乱码
    export ALLOW_MISSING_DEPENDENCIES=true       # 允许缺少依赖项继续构建
    export OF_MAINTAINER="OpenCode+DeepSeek"     # 维护者名称
    export FOX_BUILD_TYPE="Unofficial"           # 构建类型：Unofficial=非官方
    export OF_QUICK_BACKUP_LIST="/boot;/dtbo;"   # 快速备份默认分区列表

    # ===== 设备与分区布局 =====
    export TARGET_DEVICE_ALT="lmi"               # 卡刷包兼容的设备代号
    export FOX_TARGET_DEVICES="lmi,lmipro"       # 运行时兼容的设备代号列表
    export FOX_AB_DEVICE=0                       # 0=非A/B设备；1=A/B设备
    export OF_AB_DEVICE_WITH_RECOVERY_PARTITION=0 # 0=不是带独立recovery分区的A/B设备；1=是带独立recovery分区的A/B设备
    export OF_RECOVERY_AB_FULL_REFLASH_RAMDISK=0 # 0=不整包重刷ramdisk；1=双槽整包重刷recovery ramdisk（需上一项=1）
    export FOX_VIRTUAL_AB_DEVICE=0               # 0=非Virtual A/B设备；1=Virtual A/B设备
    export FOX_VENDOR_BOOT_RECOVERY=0            # 0=普通recovery分区；1=使用vendor_boot(hdr4)作为recovery
    export FOX_INSTALLER_VENDOR_BOOT_RAMDISK_INSTALL=0 # 0=安装器覆盖整个vendor_boot；1=只写vendor_boot ramdisk（仅vendor_boot构建）

    # ===== 屏幕、界面与时区 =====
    export OF_SCREEN_H=2400                      # 屏幕高度
    export OF_STATUS_H=110                       # 状态栏高度
    export OF_STATUS_INDENT_LEFT=48              # 状态栏左侧缩进
    export OF_STATUS_INDENT_RIGHT=48             # 状态栏右侧缩进
    export OF_HIDE_NOTCH=0                       # 0=显示刘海区域；1=隐藏刘海区域
    export OF_ALLOW_DISABLE_NAVBAR=0             # 0=不允许禁用导航栏；1=允许禁用导航栏
    export OF_DEFAULT_TIMEZONE="UTC-8"           # 默认时区
    export OF_USE_GREEN_LED=0                    # 0=关闭绿灯；1=开启绿灯
    export OF_FLASHLIGHT_ENABLE=1                # 0=关闭手电筒功能；1=开启手电筒功能
    export OF_CLASSIC_LEDS_FUNCTION=0            # 0=使用新版LED逻辑；1=使用旧版R9.x LED逻辑
    export OF_USE_LOCKSCREEN_BUTTON=0            # 0=滑动解锁；1=使用按钮解锁
    export OF_DISABLE_EXTRA_ABOUT_PAGE=0         # 0=显示“关于”页额外信息；1=禁用额外信息
    export OF_NO_SPLASH_CHANGE=0                 # 0=允许修改开机splash；1=禁止修改
    export FOX_NO_BLANK_DT2W=1                   # 0=关闭息屏双击唤醒；1=开启（需TW_NO_SCREEN_BLANK）
    export FOX_USE_MISANS_FONTS=0                # 0=使用InterDisplay字体；1=使用MiSans字体（约增加16MB）
    export FOX_ALLOW_EARLY_SETTINGS_LOAD=0       # 0=不提前加载；1=GUI启动早期加载设置/主题

    # ===== Shell、二进制与压缩 =====
    export FOX_ASH_IS_BASH=1                     # 0=保留ash；1=用bash替代ash
    export FOX_USE_BASH_SHELL=1                  # 0=不集成bash；1=集成并使用bash
    export FOX_USE_TAR_BINARY=1                  # 0=不集成tar；1=集成tar
    export FOX_USE_SED_BINARY=1                  # 0=不集成sed；1=集成sed
    export FOX_USE_ZSTD_BINARY=1                 # 0=不支持zstd；1=支持zstd命令
    export FOX_USE_DATE_BINARY=1                 # 0=不集成date；1=集成date命令
    export FOX_USE_XZ_UTILS=1                    # 0=不启用XZ工具；1=启用XZ工具
    export FOX_USE_LZ4_BINARY=0                  # 0=不加入lz4；1=加入/sbin/lz4
    export FOX_USE_BUSYBOX_BINARY=0              # 0=不加入busybox；1=加入/sbin/busybox（仅arm64）
    export FOX_USE_GREP_BINARY=0                 # 0=使用toybox grep；1=使用独立GNU grep
    export FOX_USE_PATCHELF_BINARY=0             # 0=不加入patchelf；1=加入/sbin/patchelf
    export FOX_USE_FSCK_EROFS_BINARY=0           # 0=不加入fsck.erofs；1=加入/sbin/fsck.erofs
    export FOX_REPLACE_TOOLBOX_GETPROP=1         # 0=保留toolbox getprop；1=替换为完整getprop
    export FOX_REMOVE_BASH=0                     # 0=保留bash；1=彻底移除bash
    export FOX_BUILD_BASH=0                      # 0=使用预编译bash；1=从源码编译bash
    export FOX_BASH_TO_SYSTEM_BIN=0              # 0=bash放/sbin；1=bash放/system/bin
    export FOX_USE_NANO_EDITOR=0                 # 0=不使用预编译nano；1=加入预编译nano
    export FOX_EXCLUDE_NANO_EDITOR=0             # 0=保留nano；1=完全排除nano
    export FOX_REMOVE_AAPT=0                     # 0=保留aapt；1=移除aapt
    export FOX_REMOVE_ZIP_BINARY=0               # 0=加入zip二进制；1=不加入zip二进制
    export FOX_EXCLUDE_ZIP=0                     # 0=从源码编译zip；1=使用预编译zip/跳过源码编译
    export OF_USE_LZMA_COMPRESSION=0             # 0=使用gzip压缩ramdisk；1=使用lzma压缩ramdisk
    export OF_USE_LZ4_COMPRESSION=0              # 0=使用gzip压缩ramdisk；1=使用lz4压缩ramdisk
    export FOX_DYNAMIC_SAMSUNG_FIX=0             # 0=不启用；1=启用三星动态分区兼容修复
    export FOX_USE_SAMSUNG_SPECIAL=0             # 0=不启用；1=启用三星设备特殊处理

    # ===== 功能、日志与安全 =====
    export FOX_ENABLE_APP_MANAGER=1              # 0=关闭应用管理器；1=启用应用管理器
    export OF_DONT_KEEP_LOG_HISTORY=0            # 0=保留历史日志；1=不保留历史日志（只覆盖lastrecoverylog）
    export OF_ADVANCED_SECURITY=0                # 0=不启用高级安全；1=启用（进入recovery前禁用ADB/MTP）
    export OF_DEVICE_WITHOUT_PERSIST=0           # 0=设备有persist分区；1=设备没有persist分区
    export OF_REPORT_HARMLESS_MOUNT_ISSUES=0     # 0=无关键载问题不报错；1=按错误报告
    export OF_MASK_GET_FOLDER_SIZE_READ_ERRORS=0 # 0=读取错误显示到控制台；1=只写入日志
    export OF_DONT_SUBSTITUTE_PERMISSIONS=0      # 0=替换OrangeFox文件权限/SELinux上下文；1=不替换
    export FOX_USE_DATA_RECOVERY_FOR_SETTINGS=0  # 0=设置存/sdcard/Fox；1=设置存/data/recovery/Fox

    # ===== 解密与文件系统 =====
    #export OF_FBE_METADATA_MOUNT_IGNORE=1       # 0=不忽略FBE元数据挂载错误；1=忽略FBE元数据挂载错误
    export OF_SKIP_FBE_DECRYPTION=0              # 0=执行FBE解密；1=跳过FBE解密
    export OF_NO_RELOAD_AFTER_DECRYPTION=0       # 0=解密后重新加载；1=解密后不重新加载
    export OF_FIX_DECRYPTION_ON_DATA_MEDIA=0     # 0=不启用；1=启用data/media解密修复
    export OF_SKIP_DECRYPTED_ADOPTED_STORAGE=0   # 0=不跳过；1=跳过已解密adopted storage
    export OF_FORCE_USE_RECOVERY_FSTAB=0         # 0=使用ROM fstab；1=只使用recovery fstab
    export OF_NO_KEYMASTER_VER_4X=0              # 0=把keymaster 4.0/4.1合并为4.x；1=不合并
    export OF_USE_LEGACY_BATTERY_SERVICES=0      # 0=使用新电池服务；1=使用旧电池服务
    export OF_FORCE_CASEFOLDING=0                # 0=自动检测casefolding；1=强制启用casefolding
    export OF_USE_AIDL_BOOT_CONTROL=0            # 0=使用HIDL boot control；1=使用AIDL boot control
    export OF_FORCE_DATA_FORMAT_F2FS=1           # 0=不强制；1=强制data分区格式化为F2FS
    export OF_FORCE_DATA_FORMAT_EXT4=0           # 0=不强制；1=强制data分区格式化为ext4
    export OF_UNBIND_SDCARD_F2FS=1               # 0=保持SD卡绑定；1=格式化F2FS时解绑SD卡
    export OF_ENABLE_FS_COMPRESSION=0            # 0=不启用f2fs压缩；1=启用f2fs压缩
    export OF_WIPE_METADATA_AFTER_DATAFORMAT=0   # 0=不自动清metadata；1=格式化data后自动清metadata
    export OF_BIND_MOUNT_SDCARD_ON_FORMAT=0      # 0=不绑定；1=格式化data后绑定/sdcard
    export OF_UNMOUNT_SDCARDS_BEFORE_REBOOT=0    # 0=重启前不卸载SD卡；1=重启前尝试卸载
    export OF_SKIP_PREBUILT_MODULES=0            # 0=加载预编译内核模块；1=跳过预编译内核模块
    export OF_FORCE_PREBUILT_KERNEL=0            # 0=不强制；1=强制使用预编译内核

    # ===== OTA、补丁与备份 =====
    export OF_KEEP_DM_VERITY=1                    # 0=不保留DM-Verity；1=保留DM-Verity
    export OF_SUPPORT_ALL_BLOCK_OTA_UPDATES=1     # 0=不支持全部块OTA；1=支持全部块OTA
    export OF_FIX_OTA_UPDATE_MANUAL_FLASH_ERROR=1 # 0=不修复；1=修复OTA手动刷入错误
    export OF_DISABLE_MIUI_OTA_BY_DEFAULT=1       # 0=默认允许MIUI OTA；1=默认禁用MIUI OTA
    export OF_NO_TREBLE_COMPATIBILITY_CHECK=1     # 0=执行Treble兼容性检查；1=跳过Treble兼容性检查
    export OF_NO_MIUI_PATCH_WARNING=1             # 0=显示MIUI补丁警告；1=不显示MIUI补丁警告
    export OF_SKIP_MULTIUSER_FOLDERS_BACKUP=1     # 0=备份多用户文件夹；1=跳过多用户文件夹备份
    export OF_DONT_PATCH_ON_FRESH_INSTALLATION=0  # 0=全新安装时执行dm-verity/强制加密补丁；1=不执行
    export OF_TWRP_COMPATIBILITY_MODE=0           # 0=OrangeFox模式；1=TWRP兼容模式
    export OF_DISABLE_MIUI_SPECIFIC_FEATURES=0    # 0=保留MIUI相关特性；1=禁用MIUI相关特性
    export OF_FORCE_MAGISKBOOT_BOOT_PATCH_MIUI=0  # 0=不强制；1=MIUI下强制用magiskboot补丁boot
    export OF_CHECK_OVERWRITE_ATTEMPTS=0          # 0=不检查；1=检查ROM覆盖recovery并倒计时
    export OF_PATCH_AVB20=0                       # 0=不补丁AVB2.0；1=补丁boot避免被原厂recovery覆盖
    export OF_SUPPORT_VBMETA_AVB2_PATCHING=0      # 0=不启用；1=通过vbmeta补丁禁用AVB2.0
    export OF_OTA_BACKUP_STOCK_BOOT_IMAGE=0       # 0=不备份；1=OTA_BAK时备份ROM的boot.img
    export OF_NO_MIUI_OTA_VENDOR_BACKUP=0         # 0=备份vendor；1=不备份vendor
    export OF_SUPPORT_OZIP_DECRYPTION=0           # 0=不支持Realme oZip解密；1=支持（还必须设置TW_OZIP_DECRYPT_KEY）
    export OF_SKIP_ORANGEFOX_PROCESS=0            # 0=执行OrangeFox补丁流程；1=跳过dm-verity/加密/boot补丁
    export FOX_PATCH_VBMETA_FLAG=0                # 0=不强制；1=强制magiskboot补丁vbmeta
    export FOX_VANILLA_BUILD=0                    # 0=完整OrangeFox；1=纯TWRP风格，跳过OrangeFox补丁
    export OF_NO_ADDITIONAL_MIUI_PROPS_CHECK=0    # 0=检查额外MIUI属性；1=不检查
    export OF_VAB_ORS_WIPE_DATA_IS_FORMAT=0       # 0=ORS的--wipe-data执行wipe；1=执行format

    # ===== 分区工具与格式化 =====
    export OF_ENABLE_ALL_PARTITION_TOOLS=1        # 0=仅启用默认分区工具；1=启用全部分区工具
    export OF_ENABLE_LPTOOLS=1                    # 0=不启用lptools；1=启用lptools（全分区工具需要）
    export FOX_USE_DMSETUP=0                      # 0=不使用dmsetup；1=格式化data前使用dmsetup
    export OF_USE_DMCTL=0                         # 0=不使用dmctl；1=格式化data前使用dmctl
    export OF_MANUAL_ROOT_VENDOR_ERROR_FIX=0      # 0=不启用；1=启用root/vendor删除错误绕过
    export OF_LOOP_DEVICE_ERRORS_TO_LOG=0         # 0=loop错误显示到控制台；1=只写入日志

    # ===== 安装器、Magisk 与更新 =====
    export OF_MANUAL_COPY_TWRES=1                 # 0=按默认流程复制TWRES；1=手动复制TWRES文件
    #export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1 # 0=不使用TWRP recovery镜像构建器；1=使用TWRP recovery镜像构建器
    export FOX_INSTALLER_DEBUG_MODE=0             # 0=正常安装日志；1=安装器调试模式
    export FOX_INSTALLER_DISABLE_AUTOREBOOT=0     # 0=安装后允许自动重启；1=禁止自动重启
    export FOX_DISABLE_UPDATEZIP=0                # 0=生成OrangeFox ZIP；1=不生成ZIP
    export FOX_MOVE_MAGISK_INSTALLER_TO_RAMDISK=0 # 0=Magisk安装包放/sdcard；1=移入ramdisk
    export OF_NO_REFLASH_CURRENT_ORANGEFOX=0      # 0=保留“刷入当前OrangeFox”；1=移除该功能
    export FOX_USE_UPDATED_MAGISKBOOT=0           # 0=使用旧magiskboot；1=使用2024+新版magiskboot

    # ===== 体积裁剪 =====
    export FOX_COMPRESS_EXECUTABLES=0             # 0=不压缩；1=用upx压缩/sbin和/system/bin中的大二进制
    export FOX_DRASTIC_SIZE_REDUCTION=0           # 0=不启用；1=大幅裁剪ramdisk
    export FOX_EXTREME_SIZE_REDUCTION=0           # 0=不启用；1=极限裁剪（自动包含上一项）

    # ===== 附加组件与 Root =====
    export FOX_DELETE_AROMAFM=1                   # 0=保留AromaFM；1=删除AromaFM
    export FOX_DELETE_MAGISK_ADDON=1              # 0=保留Magisk附加组件；1=删除Magisk附加组件
    export FOX_DELETE_INITD_ADDON=1               # 0=保留/启用initd附加组件；1=删除/禁用initd附加组件
    export OF_ENABLE_FRP_ADDON=0                  # 0=不加入FRP清除插件；1=加入FRP清除插件
    export FOX_ENABLE_KERNELSU_SUPPORT=0          # 0=不加入KernelSU支持；1=加入KernelSU支持
    export FOX_ENABLE_KERNELSU_NEXT_SUPPORT=0     # 0=不加入KernelSU Next支持；1=加入KernelSU Next支持
    export FOX_ENABLE_SUKISU_SUPPORT=0            # 0=不加入SukiSU支持；1=加入SukiSU支持

    # ===== 其他 =====
    export OF_DISPLAY_FORMAT_FILESYSTEMS_DEBUG_INFO=0 # 0=不显示格式化调试信息；1=显示

    # ===== 构建日志 =====
    if [ -n "$FOX_BUILD_LOG_FILE" ] && [ -f "$FOX_BUILD_LOG_FILE" ]; then
        export | grep "FOX" >> "$FOX_BUILD_LOG_FILE"
        export | grep "OF_" >> "$FOX_BUILD_LOG_FILE"
        export | grep "TARGET_" >> "$FOX_BUILD_LOG_FILE"
        export | grep "TW_" >> "$FOX_BUILD_LOG_FILE"
    fi
fi
#
