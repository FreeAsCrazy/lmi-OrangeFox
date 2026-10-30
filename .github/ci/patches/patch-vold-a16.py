#!/usr/bin/env python3
"""为 system/vold 应用 lmi/A16 元数据解密修复。

这里只处理两个恢复模式场景：

1. lmi 上报的 first_api_level 是过期的 29，Android 16 vold 会把
   dm-default-key 默认成旧版 v1 格式；而 fstab 里带有
   metadata_encryption=...，v1 无法处理。只要 fstab 确实包含
   metadata_encryption 选项，就强制使用 v2。

2. 恢复模式可能无法导出硬件包装的 metadata key
   （ICE/keymaster 返回 ENODATA）。此时回退到原始 metadata key，
   而不是直接中止挂载。

本补丁基于 TeamWin/android_system_vold 拉取请求 #1 中的
lmi 恢复模式解密工作，并适配 OrangeFox fox_16.0 清单使用的
AOSP 16 vold 源码。
"""

from pathlib import Path
import sys


def replace_once(text: str, old: str, new: str, what: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{what}: expected exactly one match, got {count}")
    return text.replace(old, new, 1)


def patch_metadata_cpp(root: Path) -> None:
    path = root / "system/vold/MetadataCrypt.cpp"
    text = path.read_text()

    if "OF_METADATA_HWWRAPPED_FALLBACK" not in text:
        old = """    KeyBuffer module_key;
    if (options.use_hw_wrapped_key) {
        if (!exportWrappedStorageKey(key, &module_key)) {
            LOG(ERROR) << "Failed to get ephemeral wrapped key";
            return false;
        }
    } else {
        module_key = key;
    }
"""
        new = """    KeyBuffer module_key;
    bool actual_use_hw_wrapped_key = options.use_hw_wrapped_key;
    if (actual_use_hw_wrapped_key) {
        if (!exportWrappedStorageKey(key, &module_key)) {
#ifdef OF_METADATA_HWWRAPPED_FALLBACK
            // 恢复模式可能无法导出 ICE 包装密钥。
            // 原始密钥足以挂载 metadata 加密数据。
            LOG(WARNING) << "Failed to export wrapped metadata key; using raw key";
            module_key = key;
            actual_use_hw_wrapped_key = false;
#else
            LOG(ERROR) << "Failed to get ephemeral wrapped key";
            return false;
#endif
        }
    } else {
        module_key = key;
    }
"""
        text = replace_once(text, old, new, "MetadataCrypt wrapped-key fallback")

    if "if (options.use_hw_wrapped_key) target->SetWrappedKeyV0();" in text:
        text = text.replace(
            "if (options.use_hw_wrapped_key) target->SetWrappedKeyV0();",
            "if (actual_use_hw_wrapped_key) target->SetWrappedKeyV0();",
            1,
        )

    marker = "if (options_format_version < 2 && !data_rec->metadata_encryption_options.empty())"
    if marker not in text:
        # 同步下来的源码可能带有少量本地修改，
        # 所以按声明名称定位，而不是匹配整段代码。
        start = text.find("unsigned int options_format_version")
        if start < 0:
            raise SystemExit("MetadataCrypt options_format_version: declaration not found")
        insert_at = text.find("CryptoOptions options;", start)
        if insert_at < 0:
            raise SystemExit("MetadataCrypt options_format_version: CryptoOptions not found")
        line_start = text.rfind("\n", 0, insert_at) + 1
        patch = (
            "    // lmi 的 vendor 上报 first_api_level=29，而 A16 ROM 使用\n"
            "    // v2 dm-default-key 格式；v1 无法表示 fstab 中的\n"
            "    // metadata_encryption 选项，所以只要存在这些选项就强制 v2。\n"
            "    if (options_format_version < 2 && !data_rec->metadata_encryption_options.empty()) {\n"
            "        LOG(WARNING) << \"metadata_encryption present; forcing dm-default-key format v2\";\n"
            "        options_format_version = 2;\n"
            "    }\n\n"
        )
        text = text[:line_start] + patch + text[line_start:]

    path.write_text(text)
    print("vold: MetadataCrypt.cpp patched")




def patch_fs_crypt(root: Path) -> None:
    path = root / "system/vold/FsCrypt.cpp"
    text = path.read_text()

    if "OF_METADATA_HWWRAPPED_FALLBACK" in text:
        print("vold: FsCrypt.cpp already has fallback")
        return

    old = """    KeyBuffer ephemeral_wrapped_key;
    if (options.use_hw_wrapped_key) {
        if (!exportWrappedStorageKey(key, &ephemeral_wrapped_key)) {
            LOG(ERROR) << "Failed to get ephemeral wrapped key";
            return false;
        }
    }
    return installKey(mountpoint, options, options.use_hw_wrapped_key ? ephemeral_wrapped_key : key,
                      policy);
"""
    new = """    KeyBuffer ephemeral_wrapped_key;
    bool use_hw_wrapped_key = options.use_hw_wrapped_key;
    EncryptionOptions adjusted_options = options;
    if (use_hw_wrapped_key) {
        if (!exportWrappedStorageKey(key, &ephemeral_wrapped_key)) {
#ifdef OF_METADATA_HWWRAPPED_FALLBACK
            // 恢复模式可能无法导出 ICE 包装的 FBE 密钥。
            // 安装原始密钥，让 CE/DE 初始化继续进行。
            LOG(WARNING) << "Failed to export wrapped FBE key; using raw key";
            use_hw_wrapped_key = false;
            adjusted_options.use_hw_wrapped_key = false;
#else
            LOG(ERROR) << "Failed to get ephemeral wrapped key";
            return false;
#endif
        }
    }
    return installKey(mountpoint, adjusted_options,
                      use_hw_wrapped_key ? ephemeral_wrapped_key : key, policy);
"""
    text = replace_once(text, old, new, "FsCrypt wrapped-key fallback")
    path.write_text(text)
    print("vold: FsCrypt.cpp patched")

def patch_android_bp(root: Path) -> None:
    path = root / "system/vold/Android.bp"
    text = path.read_text()
    if "-DOF_METADATA_HWWRAPPED_FALLBACK" in text:
        print("vold: Android.bp already has fallback flag")
        return

    old = """        "-Wno-unused-parameter",
"""
    new = """        "-Wno-unused-parameter",
        // OrangeFox：ICE 无法导出包装密钥时，允许使用原始 metadata 密钥
        "-DOF_METADATA_HWWRAPPED_FALLBACK",
"""
    # vold Android.bp 里可能有多个 cflags 块；
    # 只有 vold_default_flags 块用于恢复模式构建。
    start = text.find('name: "vold_default_flags"')
    if start < 0:
        raise SystemExit("Android.bp: vold_default_flags not found")
    idx = text.find(old, start)
    if idx < 0:
        raise SystemExit("Android.bp: cflags block not found")
    text = text[:idx] + new + text[idx + len(old):]
    path.write_text(text)
    print("vold: Android.bp patched")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} FOX_DIR")
    root = Path(sys.argv[1])
    for rel in ("system/vold/MetadataCrypt.cpp", "system/vold/Android.bp"):
        if not (root / rel).is_file():
            raise SystemExit(f"missing {rel}; vold source not synced")
    patch_metadata_cpp(root)
    patch_fs_crypt(root)
    patch_android_bp(root)
    print("vold: A16 metadata decryption patch applied")


if __name__ == "__main__":
    main()
