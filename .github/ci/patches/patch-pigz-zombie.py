#!/usr/bin/env python3
"""回收 TWFunc::Copy_Log() 创建后未等待的 pigz 子进程。

Copy_Log 会启动 pigz 压缩恢复模式日志，但从不等待它退出，
导致子进程在恢复模式结束前一直保持僵尸状态。
twrpTar 已经会回收自己的 pigz 子进程；这里只修复日志复制路径。
"""

from pathlib import Path
import sys


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} FOX_DIR")
    path = Path(sys.argv[1]) / "bootable/recovery/twrp-functions.cpp"
    if not path.is_file():
        raise SystemExit(f"missing {path}")
    text = path.read_text()

    marker = "pigz_status"
    if marker in text:
        print("twrp-functions.cpp pigz reap already applied")
        return

    old = """\t} else {
\t\tclose(logPipe[0]);
\t\tif (write(logPipe[1], destLogBuffer.c_str(), destLogBuffer.size()) < 0) {
\t\t\tLOGINFO("Unable to append to persistent log: %s\\n", Destination.c_str());
\t\t\tclose(logPipe[1]);
\t\t\tclose(destination_fd);
\t\t\treturn;
\t\t}
\t\tif (write(logPipe[1], srcLogBuffer.c_str(), srcLogBuffer.size()) < 0) {
\t\t\tLOGINFO("Unable to append to persistent log: %s\\n", Destination.c_str());
\t\t\tclose(logPipe[1]);
\t\t\tclose(destination_fd);
\t\t\treturn;
\t\t}
\t\tclose(logPipe[1]);
\t}
\tclose(destination_fd);
"""
    new = """\t} else {
\t\tclose(logPipe[0]);
\t\tbool log_write_failed = false;
\t\tif (write(logPipe[1], destLogBuffer.c_str(), destLogBuffer.size()) < 0) {
\t\t\tLOGINFO("Unable to append to persistent log: %s\\n", Destination.c_str());
\t\t\tlog_write_failed = true;
\t\t}
\t\tif (!log_write_failed &&
\t\t    write(logPipe[1], srcLogBuffer.c_str(), srcLogBuffer.size()) < 0) {
\t\t\tLOGINFO("Unable to append to persistent log: %s\\n", Destination.c_str());
\t\t\tlog_write_failed = true;
\t\t}
\t\tclose(logPipe[1]);
\t\tif (log_write_failed) {
\t\t\tclose(destination_fd);
\t\t\tif (pigz_pid > 0) {
\t\t\t\tint pigz_status;
\t\t\t\tTWFunc::Wait_For_Child(pigz_pid, &pigz_status, "pigz");
\t\t\t}
\t\t\treturn;
\t\t}
\t}
\tclose(destination_fd);
\tif (pigz_pid > 0) {
\t\tint pigz_status;
\t\tTWFunc::Wait_For_Child(pigz_pid, &pigz_status, "pigz");
\t}
"""
    if text.count(old) != 1:
        raise SystemExit(f"Copy_Log block: expected one match, got {text.count(old)}")
    path.write_text(text.replace(old, new, 1))
    print("patched TWFunc::Copy_Log pigz reap")


if __name__ == "__main__":
    main()
