#!/usr/bin/env python3
"""检查 OrangeFox recovery.img：解析 boot 头、解出 ramdisk(cpio)，核对关键配置。"""
import gzip
import struct
import sys
import re


def parse_boot(path):
    d = open(path, "rb").read()
    assert d[:8] == b"ANDROID!", "不是 Android boot 镜像"
    g = lambda o: struct.unpack_from("<I", d, o)[0]
    ks, rs, page, hver, osv = g(8), g(16), g(36), g(40), g(44)
    A, B, C = (osv >> 25) & 0x7F, (osv >> 20) & 0x1F, (osv >> 14) & 0x3F
    roff = page + (ks + page - 1) // page * page
    rd = d[roff:roff + rs]
    assert rd[:2] == b"\x1f\x8b", "ramdisk 不是 gzip"
    return {
        "raw_size": len(d),
        "kernel": ks,
        "ramdisk": rs,
        "page": page,
        "header": hver,
        "os": f"{A}.{B}.{C}",
        "out": gzip.decompress(rd),
    }


def walk_cpio(out):
    files = {}
    i = 0
    while i + 110 <= len(out) and out[i:i + 6] == b"070701":
        namesize = int(out[i + 94:i + 102], 16)
        filesize = int(out[i + 54:i + 62], 16)
        name = out[i + 110:i + 110 + namesize - 1].decode(errors="replace")
        hsz = (110 + namesize + 3) // 4 * 4
        files[name] = out[i + hsz:i + hsz + filesize]
        if name == "TRAILER!!!":
            break
        i = i + hsz + (filesize + 3) // 4 * 4
    return files


def main(path):
    info = parse_boot(path)
    files = walk_cpio(info["out"])
    print(f"镜像: {path}")
    print(f"  boot header v{info['header']}  page={info['page']}  os={info['os']}  "
          f"kernel={info['kernel']/1048576:.1f}MB  ramdisk={info['ramdisk']/1048576:.1f}MB")
    print(f"  ramdisk 解压后 {len(info['out'])/1048576:.1f}MB, 共 {len(files)} 个条目")

    keys = ["system/bin/recovery"]
    print("\n-- 关键文件 --")
    for k in keys:
        print(f"  {k}: {'有' if k in files else '缺失'}"
              + (f" ({len(files[k])/1048576:.1f}MB)" if k in files else ""))

    print("\n-- 维护者 / 语言 相关命中 --")
    hits = 0
    for name, blob in files.items():
        if not blob or len(blob) > 4 * 1024 * 1024:
            continue  # 大二进制单独处理
        try:
            text = blob.decode("utf-8")
        except UnicodeDecodeError:
            continue
        for kw in ("opencode", "of_maintainer", "OF_MAINTAINER", "zh_CN", "maintainer"):
            for m in re.finditer(re.escape(kw), text):
                line_start = text.rfind("\n", 0, m.start()) + 1
                line_end = text.find("\n", m.end())
                line = text[line_start:line_end if line_end != -1 else len(text)]
                print(f"  [{name}] {line.strip()[:160]}")
                hits += 1
                break
    # 二进制里只报是否存在
    for name, blob in files.items():
        if not blob or len(blob) <= 4 * 1024 * 1024:
            continue
        for kw in (b"opencode", b"of_maintainer", b"zh_CN"):
            if kw in blob:
                print(f"  [{name}] 二进制含 {kw.decode()}")
                hits += 1
    if not hits:
        print("  (无)")

    print("\n-- recovery.fstab --")
    fstab = files.get("system/etc/recovery.fstab", b"").decode(errors="replace")
    for line in fstab.splitlines():
        s = line.strip()
        if s and not s.startswith("#"):
            print("  " + s[:160])
    print(f"  erofs 支持: {'是' if 'erofs' in fstab else '否'}")

    # 关键属性
    for pname in ("prop.default", "default.prop", "system/etc/prop.default"):
        if pname in files:
            print(f"\n-- {pname} --")
            for line in files[pname].decode(errors="replace").splitlines():
                if any(k in line for k in ("fox", "twrp", "maintainer", "product.device",
                                           "build.version", "security_patch", "shipping")):
                    print("  " + line.strip()[:160])


if __name__ == "__main__":
    for p in sys.argv[1:]:
        main(p)
        print()
