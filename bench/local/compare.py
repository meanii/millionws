#!/usr/bin/env python3
"""Build a comparison table from benchmark result directories.

Usage: compare.py DIR [DIR ...] > comparison.md

Each DIR is a run written by run.sh. Runs of the same variant are grouped and
reported as the median, with the range in brackets when there is more than one
run. Variants keep the order in which they first appear on the command line.
"""

import json
import os
import statistics
import sys


def load(dirs):
    groups = {}
    for d in dirs:
        path = os.path.join(d, "summary.json")
        if not os.path.exists(path):
            continue
        with open(path) as f:
            s = json.load(f)
        groups.setdefault(s["variant"], []).append(s)
    return groups


def stat(values, fmt):
    values = [v for v in values if v is not None]
    if not values:
        return "n/a"
    mid = fmt(statistics.median(values))
    if len(values) == 1 or min(values) == max(values):
        return mid
    return f"{mid} ({fmt(min(values))} to {fmt(max(values))})"


def stop_label(run):
    if run.get("oom_killed"):
        return "OOM kill"
    reason = run["stop_reason"]
    if reason.startswith("no growth"):
        return "stopped growing, server still up"
    return reason


def main():
    groups = load(sys.argv[1:])
    count = lambda v: f"{v:,.0f}"
    kib = lambda v: f"{v / 1024:.2f}"
    ms = lambda v: f"{v:,.0f}"

    print("| Variant | Runs | Peak connections | KiB per connection | Kernel KiB | Go (anon) KiB | CPU near peak | Echo p99 ms | Stopped by |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    for variant, runs in groups.items():
        b = [r["bytes_per_connection"] for r in runs]
        stops = sorted({stop_label(r) for r in runs})
        print("| " + " | ".join([
            f"`{variant}`",
            str(len(runs)),
            stat([r["peak_connections"] for r in runs], count),
            stat([x["cgroup_total"] for x in b], kib),
            stat([x.get("kernel_other") for x in b], kib),
            stat([x["cgroup_anon"] for x in b], kib),
            stat([r["cpu_pct_near_peak_avg"] for r in runs], lambda v: f"{v:.0f}%"),
            stat([r["at_peak"]["echo_p99_ms"] for r in runs], ms),
            "; ".join(stops),
        ]) + " |")


if __name__ == "__main__":
    main()
