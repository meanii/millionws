#!/usr/bin/env python3
"""Socket memory while the server is frozen: 1M connections (killed) vs 250k (bounded).
Usage: plot_tcp_bound.py <memwatch dir> <out.png>"""
import csv, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

src, out = sys.argv[1:3]
sec = lambda t: sum(int(p) * m for p, m in zip(t.split(":"), (3600, 60, 1)))
def load(name, start):
    rows = []
    for x in csv.DictReader(open(f"{src}/{name}.csv")):
        try:
            rows.append((sec(x["local"]) - sec(start), int(x["current_mib"]), int(x["sock_mib"])))
        except (TypeError, ValueError):
            pass
    return rows
fig, axes = plt.subplots(1, 2, figsize=(15, 5))
for ax, (name, start, freeze, conns, title) in zip(axes, [
        ("mw_bound_60", "17:14:21", 60, 250_003, "250,003 connections, 60 s freeze: survived"),
        ("mw_rmem_30", "17:00:34", 30, 1_000_009, "1,000,009 connections, 30 s freeze: killed on resume")]):
    r = [x for x in load(name, start) if -5 <= x[0] <= freeze + 12]
    ax.plot([x[0] for x in r], [x[1] for x in r], color="black", lw=2, label="container memory")
    ax.plot([x[0] for x in r], [x[2] for x in r], color="red", lw=2, label="socket buffers")
    bound = conns * 4 / 1024
    ax.axhline(bound, color="red", ls=":", lw=1.2)
    ax.text(freeze + 11, bound, f"connections x 4 KiB = {bound:,.0f} MiB", color="red", ha="right", va="bottom", fontsize=8)
    ax.axhline(6144, color="gray", ls="--", lw=1)
    ax.text(-4, 6144, "container limit 6,144 MiB", color="gray", va="bottom", fontsize=8)
    ax.axvspan(0, freeze, color="#ffd43b", alpha=0.25)
    ax.set_title(title, fontsize=10, color="green" if "survived" in title else "red")
    ax.set_xlabel("seconds from the freeze start (yellow: server frozen)")
    ax.set_ylim(0, 9800)
axes[0].set_ylabel("MiB")
axes[0].legend(loc="upper left", fontsize=8)
fig.suptitle("While the server does not read, each socket that receives a message is charged one 4 KiB page, even past the container limit", fontsize=11)
fig.tight_layout()
fig.savefig(out, dpi=105)
print("wrote", out)
