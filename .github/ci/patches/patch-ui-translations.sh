#!/bin/bash
# 修正 OrangeFox 中文翻译：
# 备份 -> 平均速度 -> 文件 / 图片
# 这里的“图片”实际指镜像，正确翻译应为“镜像”。
set -euo pipefail
: "${FOX_DIR:?FOX_DIR not set}"

files=(
  "$FOX_DIR/bootable/recovery/gui/theme/extra-languages/languages/zh_CN.xml"
  "$FOX_DIR/bootable/recovery/gui/theme/common/languages/zh_CN.xml"
)

found=0
for f in "${files[@]}"; do
  [ -f "$f" ] || continue
  if grep -q 'name="backup_av_img"' "$f"; then
    sed -i -E 's|(<string name="backup_av_img">)图片(</string>)|\1镜像\2|' "$f"
    echo "已修正: $f"
    grep -n 'name="backup_av_img"' "$f"
    found=1
  fi
done

if [ "$found" = 0 ]; then
  echo "警告：没有找到 backup_av_img 翻译项" >&2
fi
