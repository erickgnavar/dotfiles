#!/usr/bin/env python3
"""Stream recent per-process CPU usage to Eww (100% = one logical CPU)."""

import json
import os
import time
from pathlib import Path


TICKS = os.sysconf("SC_CLK_TCK")
PAGE_MIB = os.sysconf("SC_PAGE_SIZE") / (1024 * 1024)


def snapshot(root=Path("/proc")):
    processes = {}
    for entry in root.iterdir():
        if not entry.name.isdecimal():
            continue
        try:
            stat = (entry / "stat").read_text()
            # comm may contain spaces and parentheses; fields after it start at #3.
            start, end = stat.index("("), stat.rindex(")")
            fields = stat[end + 2 :].split()
            processes[int(entry.name)] = (
                fields[19],
                stat[start + 1 : end],
                int(fields[11]) + int(fields[12]),
                max(0, int(fields[21])) * PAGE_MIB,
            )
        except (OSError, ValueError, IndexError):
            # A process can exit or become inaccessible during the scan.
            continue
    return processes


def top_processes(previous, current, elapsed, sort_by="cpu"):
    rows = []
    for pid, (started, name, ticks, memory) in current.items():
        old = previous.get(pid)
        # Skip new/reused PIDs until they have a complete sample interval.
        if old is None or old[0] != started:
            if sort_by == "cpu":
                continue
            percent = 0
        else:
            percent = max(0, ticks - old[2]) * 100 / (TICKS * elapsed)
        rows.append(
            {
                "pid": pid,
                "name": name,
                "cpu": round(percent, 1),
                "memory": round(memory, 1),
            }
        )
    return sorted(rows, key=lambda row: (-row[sort_by], row["pid"]))[:10]


def main():
    previous = snapshot()
    sampled_at = time.monotonic()
    while True:
        time.sleep(2)
        current = snapshot()
        now = time.monotonic()
        data = {
            key: top_processes(previous, current, now - sampled_at, key)
            for key in ("cpu", "memory")
        }
        print(json.dumps(data), flush=True)
        previous, sampled_at = current, now


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
