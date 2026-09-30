#!/usr/bin/env python3
"""Draw two charts from the raw evidence of the Mumbai run (all times IST).
  plot_run.py <prometheus_range.json> <server_sampler.csv> <memwatch_1hz.csv> <out_dir>
Needs matplotlib.
"""
import csv, datetime, json, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.dates as mdates
import matplotlib.pyplot as plt

prom, sampler, memwatch, out = sys.argv[1:5]
IST = datetime.timezone(datetime.timedelta(hours=5, minutes=30))
day = datetime.date(2026, 9, 30)
dt = lambda unix: datetime.datetime.fromtimestamp(float(unix), IST)
series = json.load(open(prom))["series"]
def get(name):
    r = series[name]["result"][0]["values"]
    return [dt(t) for t, _ in r], [float(v) if v != "NaN" else float("nan") for _, v in r]
def hms(s, base=day):
    h, m, sec = map(int, s.split(":"))
    return datetime.datetime(base.year, base.month, base.day, h, m, sec, tzinfo=IST)
KILLS = [("10:31:18", "OOM kill 1\n30 s CPU profile\n(unintended)"), ("11:07:51", "OOM kill 2\n30 s CPU profile\n(unintended)"), ("11:33:53", "OOM kill 3\n30 s CPU profile\n(on purpose)")]
fmt = mdates.DateFormatter("%H:%M", tz=IST)

# chart 1: overview
rows = list(csv.DictReader(open(sampler)))
st = [datetime.datetime.strptime(r["local"], "%Y-%m-%dT%H:%M:%S%z") for r in rows]
cont = [float(r["container_mem_mib"]) if r["container_mem_mib"] else float("nan") for r in rows]
fig, ax = plt.subplots(3, 1, figsize=(14, 9), sharex=True)
t, v = get("server_connections_active")
ax[0].plot(t, [x / 1e6 for x in v], color="#2b8a3e"); ax[0].set_ylabel("connections held by\nthe server (millions)"); ax[0].set_ylim(0, 1.1)
ax[1].plot(st, cont, color="#1c7ed6", label="server container memory (cgroup)")
ax[1].axhline(6144, color="red", ls="--", lw=1, label="container limit 6,144 MiB")
ax[1].axhline(6144 * 0.9, color="orange", ls=":", lw=1, label="admission guard (90%) 5,530 MiB")
ax[1].set_ylabel("MiB"); ax[1].legend(loc="lower right", fontsize=8); ax[1].set_ylim(0, 6800)
t, v = get("echo_latency_p99_seconds_30s")
ax[2].semilogy(t, [max(x, 1e-3) if x == x else float("nan") for x in v], color="#e8590c"); ax[2].set_ylabel("echo p99 (s), log")
for a in ax:
    for k, label in KILLS:
        a.axvline(hms(k), color="red", alpha=0.35, lw=1)
for k, label in KILLS:
    ax[0].annotate(label, (hms(k), 1.02), fontsize=7, ha="center", va="bottom", color="red")
ax[2].xaxis.set_major_formatter(fmt); ax[2].set_xlabel("time, IST (UTC+05:30), 2026-09-30")
fig.suptitle("Mumbai run: 1,000,000 connections on one m7i-flex.large (6 GiB container), three OOM kills, each during a 30 s CPU profile", fontsize=11)
fig.tight_layout(); fig.savefig(f"{out}/timeline_overview_IST.png", dpi=110); plt.close(fig)

# chart 2: 1 Hz zoom on the third kill
mw = list(csv.DictReader(open(memwatch)))
mw = [r for r in mw if "11:33:20" <= r["local"] <= "11:34:12"]
x = [hms(r["local"]) for r in mw]
fig, ax = plt.subplots(2, 1, figsize=(12, 7), sharex=True)
ax[0].plot(x, [int(r["current_mib"]) for r in mw], color="black", lw=2, label="container total")
ax[0].plot(x, [int(r["anon_mib"]) for r in mw], label="anon (Go heap)")
ax[0].plot(x, [int(r["sock_mib"]) for r in mw], label="sock (socket buffers)", color="red")
ax[0].plot(x, [int(r["kernel_mib"]) for r in mw], label="kernel (slab)", color="gray")
ax[0].axhline(6144, color="red", ls="--", lw=1); ax[0].text(x[0], 6180, "limit 6,144 MiB", color="red", fontsize=8)
ax[0].axvline(hms("11:33:39"), color="green", ls="--"); ax[0].text(hms("11:33:39"), 4200, " 30 s CPU profile starts", color="green", fontsize=9)
ax[0].set_ylabel("MiB"); ax[0].legend(loc="center left", fontsize=8)
ax[1].plot(x, [int(r["estab"]) / 1e6 for r in mw], color="#2b8a3e"); ax[1].set_ylabel("established sockets (millions)")
ax[1].xaxis.set_major_formatter(mdates.DateFormatter("%H:%M:%S", tz=IST)); ax[1].set_xlabel("time, IST, 1 s samples")
fig.suptitle("Third kill, 1 s resolution: socket-buffer memory grows ~130 MiB/s while the CPU profile runs", fontsize=11)
fig.tight_layout(); fig.savefig(f"{out}/third_kill_1hz_IST.png", dpi=110); plt.close(fig)
print("charts written to", out)
