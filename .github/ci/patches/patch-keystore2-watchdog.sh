#!/bin/bash
# 仅修复恢复模式中的 Keystore2 watchdog。
#
# Keystore2 会无条件启动 await_boot_completed 等待。恢复模式永远不会
# 设置 sys.boot_completed，因此该 watchdog 在 5 分钟超时后会每 30 秒
# 报告一次。不要把 sys.boot_completed 设为 1，因为 Keystore2 会用这个
# 标志启动 key-blob GC。
#
# 这里改为标记恢复模式的 keystore2 服务，只跳过这一个等待线程；
# Keystore2 的其他 watchdog 检查点继续保留。
set -euo pipefail
: "${FOX_DIR:?FOX_DIR not set}"

MAIN="$FOX_DIR/system/security/keystore2/src/keystore2_main.rs"
RC="$FOX_DIR/bootable/recovery/etc/init/keystore2.rc"

if [ -f "$MAIN" ]; then
  if ! grep -q 'KEYSTORE2_RECOVERY' "$MAIN"; then
    python3 - "$MAIN" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = '    std::thread::spawn(keystore2::globals::await_boot_completed);\n'
new = (
    '    if std::env::var_os("KEYSTORE2_RECOVERY").is_none() {\n'
    '        std::thread::spawn(keystore2::globals::await_boot_completed);\n'
    '    }\n'
)
if s.count(old) != 1:
    raise SystemExit(f"keystore2_main.rs: expected one watchdog line, got {s.count(old)}")
p.write_text(s.replace(old, new, 1))
print("patched keystore2 await_boot_completed guard")
PY
  else
    echo "keystore2_main.rs already patched"
  fi
  grep -q 'KEYSTORE2_RECOVERY' "$MAIN"
else
  echo "警告：未找到 keystore2_main.rs" >&2
fi

if [ -f "$RC" ]; then
  if ! grep -q 'setenv KEYSTORE2_RECOVERY 1' "$RC"; then
    sed -i '/^service keystore2 /a\    setenv KEYSTORE2_RECOVERY 1' "$RC"
  fi
  grep -q 'setenv KEYSTORE2_RECOVERY 1' "$RC"
  grep -n -A6 '^service keystore2 ' "$RC"
else
  echo "警告：未找到 recovery keystore2.rc" >&2
fi
