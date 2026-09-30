#!/usr/bin/env python3
"""Plot the container memory of each stall test (1 Hz traces from memwatch.sh).
Usage: plot_stalls.py <memwatch dir> <out.png>
Each test freezes the server (SIGSTOP) for N seconds at about 1M connections.
The tests are listed below with the time the freeze started (from the run log).
"""
import csv, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

src, out = sys.argv[1:3]
TESTS = [  # file, freeze start (IST), seconds, container limit MiB, result
    ("memwatch_limit6g_5s.csv", "13:20:38.8", 5, 6144, "survived"),
    ("memwatch_limit6g_9s.csv", "13:23:45.9", 9, 6144, "killed"),
    ("memwatch_limit6500m_9s.csv", "13:29:53.1", 9, 6500, "survived"),
    ("memwatch_limit6500m_14s.csv", "13:33:04.1", 14, 6500, "killed"),
    ("memwatch_7g_14s.csv", "14:57:31.2", 14, 7168, "killed"),
]
sec = lambda t: sum(float(p) * m for p, m in zip(t.split(":"), (3600, 60, 1)))
fig, axes = plt.subplots(1, len(TESTS), figsize=(18, 4.6), sharey=False)
for ax, (f, start, dur, limit, res) in zip(axes, TESTS):
    rows = []
    for x in csv.DictReader(open(f"{src}/{f}")):
        try:
            rows.append((sec(x["local"]) - sec(start), int(x["current_mib"]), int(x["sock_mib"])))
        except (TypeError, ValueError):
            pass
    rows = [r for r in rows if -8 <= r[0] <= dur + 6]
    ax.plot([r[0] for r in rows], [r[1] for r in rows], color="black", lw=2, label="container memory")
    ax.plot([r[0] for r in rows], [r[2] for r in rows], color="red", lw=1.5, label="socket buffers")
    ax.axhline(limit, color="red", ls="--", lw=1)
    ax.axvspan(0, dur, color="#ffd43b", alpha=0.25)
    base = sorted(r[1] for r in rows if r[0] < 0)[len(rows) // 4]
    ax.set_title(f"{dur} s freeze, limit {limit} MiB\n{res.upper()}  (headroom {limit - base} MiB)", fontsize=10, color="green" if res == "survived" else "red")
    ax.set_xlabel("seconds from the freeze start")
    ax.set_ylim(0, max(limit, max(r[1] for r in rows)) * 1.08)
axes[0].set_ylabel("MiB")
axes[0].legend(fontsize=8, loc="center left")
fig.suptitle("Stalling the server at ~1M connections: socket buffers grow ~130 MiB/s; the container is killed if it reaches its limit", fontsize=11)
fig.tight_layout()
fig.savefig(out, dpi=105)
print("wrote", out)
