#!/usr/bin/env python3
"""校验生成的 recovery 镜像：boot 头和 ramdisk 布局。"""
from __future__ import annotations

import gzip
import struct
import sys


def main() -> None:
    data = open(sys.argv[1], "rb").read()
    ok = True

    def check(condition: bool, message: str) -> None:
        nonlocal ok
        print(("  [OK]   " if condition else "  [FAIL] ") + message)
        ok = ok and condition

    check(data[:8] == b"ANDROID!", "boot 头 magic = ANDROID!")
    word = lambda offset: struct.unpack_from("<I", data, offset)[0]
    kernel_size, ramdisk_size, page_size, header_version, os_version = (
        word(8), word(16), word(36), word(40), word(44)
    )
    print(f"  header_version={header_version} page_size={page_size} "
          f"kernel={kernel_size / 1048576:.1f}MB "
          f"ramdisk={ramdisk_size / 1048576:.1f}MB")
    check(page_size in (2048, 4096, 8192, 16384), f"page_size 合法（{page_size}）")
    check(header_version in (0, 1, 2, 3, 4), f"header_version 合法（{header_version}）")

    version = (
        (os_version >> 25) & 0x7F,
        (os_version >> 20) & 0x1F,
        (os_version >> 14) & 0x3F,
    )
    print(f"  os_version={version[0]}.{version[1]}.{version[2]}")

    ramdisk_offset = page_size + (kernel_size + page_size - 1) // page_size * page_size
    ramdisk = data[ramdisk_offset:ramdisk_offset + ramdisk_size]
    check(ramdisk[:2] == b"\x1f\x8b", "ramdisk 是 gzip")

    out = gzip.decompress(ramdisk)
    print(f"  ramdisk 解压后 {len(out) / 1048576:.1f}MB")

    index = 0
    files: dict[str, tuple[int, int]] = {}
    while index + 110 <= len(out) and out[index:index + 6] == b"070701":
        name_size = int(out[index + 94:index + 102], 16)
        file_size = int(out[index + 54:index + 62], 16)
        name = out[index + 110:index + 110 + name_size - 1].decode(errors="replace")
        header_size = (110 + name_size + 3) // 4 * 4
        files[name] = (file_size, index + header_size)
        if name == "TRAILER!!!":
            break
        index += header_size + (file_size + 3) // 4 * 4

    check("system/bin/recovery" in files, "ramdisk 里有 system/bin/recovery")
    fstab = files.get("system/etc/recovery.fstab")
    if fstab:
        text = out[fstab[1]:fstab[1] + fstab[0]].decode(errors="replace")
        check("erofs" in text, "recovery.fstab 支持 erofs")

    recovery = files.get("system/bin/recovery")
    if recovery:
        blob = out[recovery[1]:recovery[1] + recovery[0]]
        print(f"  recovery 二进制 {recovery[0] / 1048576:.1f}MB")
        print(f"  [信息] 含维护者串 opencode: {b'opencode' in blob}")
        print(f"  [信息] 含 of_maintainer 键:  {b'of_maintainer' in blob}")
        print(f"  [信息] 含默认语言 zh_CN:     {b'zh_CN' in blob}")

    print("\n校验结论：" + ("通过" if ok else "有问题（见上面 [FAIL]）"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
