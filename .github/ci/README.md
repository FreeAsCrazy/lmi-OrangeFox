# .github/ci

本目录集中放置 OrangeFox 构建用的 CI 脚本、补丁和裁剪配置。

## 目录结构

```text
.github/ci/
├── README.md
├── setup-env.sh
├── sync-source.sh
├── apply-patches.sh
├── build-recovery.sh
├── collect-image.sh
├── verify-recovery.py
├── patches/
│   ├── patch-vold-a16.py
│   ├── patch-pigz-zombie.py
│   ├── patch-keystore2-watchdog.sh
│   └── patch-ui-translations.sh
└── trim/
    ├── 16.0.txt
    ├── 16.0.replaces.xml
    └── generate-remove-manifest.sh
```

## 入口脚本

| 脚本 | 作用 |
|---|---|
| `setup-env.sh` | 清理预装工具、创建 swap、安装依赖、安装 repo、准备 JDK。 |
| `sync-source.sh` | `repo init`、生成裁剪 manifest、`repo sync`、删除 `.repo` 和 GKI 预编译内核。 |
| `apply-patches.sh` | 设备树 A16 适配、源码兼容修补，并调用 `patches/` 下的补丁。 |
| `build-recovery.sh` | 配置 lunch 和 ccache，编译 `recoveryimage`，只生成 `recovery.img`。 |
| `collect-image.sh` | 按 `OrangeFox-<分支>-lmi-<年月日时分>.img` 命名、校验并放入 `dist/`。 |
| `verify-recovery.py` | 校验 boot 头、ramdisk 布局、`system/bin/recovery` 和 erofs。 |

工作流只负责调用这些脚本和上传 artifact，不再内联大段构建逻辑。

---

# patches/

存放 **具体补丁实现脚本**，不是 `.patch` 文本目录。

| 文件 | 类型 | 作用 |
|---|---|---|
| `patch-vold-a16.py` | Python | 修补 A16 `system/vold`：`MetadataCrypt.cpp`、`FsCrypt.cpp`、`Android.bp`。处理 ICE 硬件包装密钥导出失败时回退 raw key，并在 fstab 含 `metadata_encryption` 时强制 dm-default-key v2。 |
| `patch-pigz-zombie.py` | Python | 修补 `bootable/recovery/twrp-functions.cpp` 的 `TWFunc::Copy_Log`：等待 pigz 子进程，避免 recovery 中留下僵尸进程。 |
| `patch-keystore2-watchdog.sh` | Shell | 修补 recovery 的 Keystore2 watchdog：跳过 `await_boot_completed` 等待线程，并在 `keystore2.rc` 中设置 `KEYSTORE2_RECOVERY=1`。 |
| `patch-ui-translations.sh` | Shell | 修正 OrangeFox 中文翻译：把 `backup_av_img` 的“图片”改为“镜像”。 |

`apply-patches.sh` 先完成设备树和 A16 源码兼容修补，再调用：

```sh
python3 "$CI_DIR/patches/patch-vold-a16.py" "$FOX_DIR"
bash "$CI_DIR/patches/patch-keystore2-watchdog.sh"
python3 "$CI_DIR/patches/patch-pigz-zombie.py" "$FOX_DIR"
bash "$CI_DIR/patches/patch-ui-translations.sh"
```

编写约定：

- 脚本必须可重复执行：已经打过的补丁要能检测到并跳过。
- Python 补丁使用 `FOX_DIR` 作为参数；Shell 补丁从环境变量读取 `FOX_DIR`。
- 找不到目标文件或目标代码块数量异常时，应明确报错并退出非零。
- 新增补丁脚本后，必须同时在 `apply-patches.sh` 中增加调用。
- 纯配置清单不要放在这里，放到 `trim/`。

---

# trim/

存放 **repo 项目裁剪配置和生成脚本**。

| 文件 | 用途 |
|---|---|
| `16.0.txt` | Android 16 构建的裁剪 baseline。每行一个 repo 项目路径，当前共 91 条。 |
| `16.0.replaces.xml` | 追加到 `remove.xml` 的项目替换片段，例如 libvpx/libwebm 改用 AOSP、foxcli 固定提交。 |
| `generate-remove-manifest.sh` | 读取 manifest 和裁剪清单，应用前缀规则，生成 `.repo/local_manifests/remove.xml`。 |

`sync-source.sh` 中的调用：

```sh
bash "$GITHUB_WORKSPACE/.github/ci/trim/generate-remove-manifest.sh" \
  "$GITHUB_WORKSPACE/manifest-resolved.xml" \
  "$GITHUB_WORKSPACE/.github/ci/trim/16.0.txt" \
  ".repo/local_manifests/remove.xml" \
  "$GITHUB_WORKSPACE/.github/ci/trim/16.0.replaces.xml"
```

前缀规则由 `generate-remove-manifest.sh` 维护，例如：

```text
cts/*
device/generic/*
device/google/*
kernel/prebuilts/*
test/vts/*
```

## 裁剪清单格式

一行一个项目路径，必须与 `repo manifest` 输出里的 `path` 完全一致：

```text
device/xiaomi/mondrian
external/clang
external/cronet
tools/tradefederation/contrib
```

规则：

- 不要加引号。
- 不要加前导 `/`、`./` 或尾部 `/`。
- 不要缩进。
- 空行会被忽略。
- `#` 后面的内容会被当作注释忽略。
- 建议按字母排序，方便查看 diff。
- 只列确实不需要的项目；删错会导致构建缺模块。

## 替换片段格式

`16.0.replaces.xml` 是 `<manifest>` 内部的片段，不是完整 XML 文件：

```xml
<remove-project path="external/libvpx" />
<remove-project path="external/libwebm" />
<project path="external/libvpx" name="platform/external/libvpx" remote="aosp" revision="..." />
```

它会在生成 `remove.xml` 时追加到 `<manifest>` 内。

## 新增或删除项目

1. 在 `16.0.txt` 中增加或删除一行。
2. 确认该项目在 `repo manifest` 的 `path` 中存在。
3. 不要删除设备树构建必需的模块。
4. 重新跑工作流，确认 `repo sync` 成功且 `recoveryimage` 能完成。
5. 关注日志：

```text
== 自动剔除 N 个项目（前缀规则 + 裁剪表 M 条）==
```

---

# 职责划分

```text
.github/ci/setup-env.sh             # 构建环境
.github/ci/sync-source.sh           # 源码同步
.github/ci/apply-patches.sh         # 补丁入口
.github/ci/build-recovery.sh        # 编译
.github/ci/collect-image.sh         # 收集镜像
.github/ci/verify-recovery.py       # 镜像校验
.github/ci/patches/                 # 具体补丁脚本
.github/ci/trim/                    # 裁剪清单、替换片段、生成脚本
```

`16.0.txt` 和 `16.0.replaces.xml` 是可审查的数据；  
前缀规则和 XML 拼装逻辑在 `generate-remove-manifest.sh` 中。
