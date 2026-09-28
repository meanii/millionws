#!/usr/bin/env python3
"""Sample the server container while a benchmark runs and write a summary.

Two sources are read every few seconds:

- the container's cgroup files, which count all memory charged to the
  container, including kernel socket buffers that the Go process RSS does not
  show, and keep working after the server stops answering;
- Prometheus, for server metrics (connections, goroutines, file descriptors,
  Go heap) and load generator metrics (dial errors, echo latency).

Usage:
    record.py idle --container ID --out DIR
    record.py run  --container ID --out DIR [--hold S] [--plateau S] [--max S]

Standard library only.
"""

import argparse
import csv
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request

PROM = os.environ.get("PROM_URL", "http://127.0.0.1:19090")
STEP = 2  # seconds between samples

# Read from the server's /metrics at the same moment as the cgroup files, so
# both describe the same instant. Prometheus keeps returning the last scraped
# value for a few seconds after the server dies.
SERVER_METRICS = os.environ.get("SERVER_METRICS_URL", "http://127.0.0.1:18080/metrics")
SERVER_FIELDS = {
    "millionws_connections_active": "server_conns",
    "go_goroutines": "goroutines",
    "process_open_fds": "open_fds",
    "process_resident_memory_bytes": "process_rss",
    "go_memstats_heap_inuse_bytes": "go_heap_inuse",
    "go_memstats_stack_inuse_bytes": "go_stack_inuse",
    "millionws_connections_rejected_total": "rejected",
}

QUERIES = {
    "loadgen_conns": "sum(loadgen_connections_active)",
    "loadgen_target": "sum(loadgen_connections_target)",
    "dial_errors_15s": "sum(increase(loadgen_dial_errors_total[15s]))",
    "echo_rate": "sum(rate(loadgen_messages_received_total[30s]))",
    "echo_p50_ms": "1000 * histogram_quantile(0.50, sum by (le) (rate(loadgen_echo_latency_seconds_bucket[30s])))",
    "echo_p99_ms": "1000 * histogram_quantile(0.99, sum by (le) (rate(loadgen_echo_latency_seconds_bucket[30s])))",
}

FIELDS = [
    "t", "state", "server_conns", "loadgen_conns", "loadgen_target",
    "cg_memory", "cg_anon", "cg_sock", "cg_kernel", "cg_slab", "cg_percpu", "cg_file", "cg_peak",
    "oom_kills", "cpu_pct", "pids", "process_rss", "go_heap_inuse",
    "go_stack_inuse", "goroutines", "open_fds", "dial_errors_15s",
    "echo_rate", "echo_p50_ms", "echo_p99_ms", "conntrack", "rejected",
]


def prom(query):
    url = f"{PROM}/api/v1/query?" + urllib.parse.urlencode({"query": query})
    try:
        with urllib.request.urlopen(url, timeout=3) as r:
            data = json.load(r)["data"]["result"]
    except Exception:
        return None
    if not data:
        return None
    v = float(data[0]["value"][1])
    return None if v != v else v  # NaN from empty histograms


def scrape_server():
    out = dict.fromkeys(SERVER_FIELDS.values())
    try:
        with urllib.request.urlopen(SERVER_METRICS, timeout=3) as r:
            for line in r.read().decode().splitlines():
                name, _, value = line.partition(" ")
                if name in SERVER_FIELDS:
                    out[SERVER_FIELDS[name]] = float(value)
    except Exception:
        pass
    return out


def prom_vector(query):
    url = f"{PROM}/api/v1/query?" + urllib.parse.urlencode({"query": query})
    try:
        with urllib.request.urlopen(url, timeout=3) as r:
            return {tuple(sorted(x["metric"].items())): float(x["value"][1])
                    for x in json.load(r)["data"]["result"]}
    except Exception:
        return {}


def read(path):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return ""


def kv(text):
    out = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) == 2:
            out[parts[0]] = int(parts[1])
    return out


def docker_state(cid):
    r = subprocess.run(
        ["docker", "inspect", "-f", "{{.State.Status}} {{.State.OOMKilled}} {{.State.ExitCode}}", cid],
        capture_output=True, text=True)
    return r.stdout.strip() or "gone"


def conntrack_count():
    # Container-to-container traffic is tracked in the Docker host network
    # namespace, which is not the host's own under rootless Docker, so read it
    # from the netwatch container that shares that namespace.
    r = subprocess.run(
        ["docker", "exec", "millionws-bench-netwatch-1", "cat", "/proc/sys/net/netfilter/nf_conntrack_count"],
        capture_output=True, text=True)
    return int(r.stdout) if r.stdout.strip() else None


class Sampler:
    def __init__(self, cid):
        self.cid = cid
        # Resolve the cgroup from the container's init process. This works for
        # rootful and rootless Docker, which use different cgroup trees.
        pid = subprocess.run(["docker", "inspect", "-f", "{{.State.Pid}}", cid],
                             capture_output=True, text=True, check=True).stdout.strip()
        rel = read(f"/proc/{pid}/cgroup").strip().split("::", 1)[1]
        self.cg = "/sys/fs/cgroup" + rel
        self.last_cpu = None

    def sample(self):
        s = {"t": round(time.time(), 1)}
        stat = kv(read(f"{self.cg}/memory.stat"))
        cur = read(f"{self.cg}/memory.current").strip()
        peak = read(f"{self.cg}/memory.peak").strip()
        s["cg_memory"] = int(cur) if cur else None
        s["cg_peak"] = int(peak) if peak else None
        s["cg_anon"] = stat.get("anon")
        s["cg_sock"] = stat.get("sock")
        s["cg_kernel"] = stat.get("kernel")
        s["cg_slab"] = stat.get("slab")
        s["cg_percpu"] = stat.get("percpu")
        s["cg_file"] = stat.get("file")
        s["oom_kills"] = kv(read(f"{self.cg}/memory.events")).get("oom_kill")
        pids = read(f"{self.cg}/pids.current").strip()
        s["pids"] = int(pids) if pids else None

        usage = kv(read(f"{self.cg}/cpu.stat")).get("usage_usec")
        now = time.monotonic()
        if usage is not None and self.last_cpu:
            du, dt = usage - self.last_cpu[0], now - self.last_cpu[1]
            s["cpu_pct"] = round(100 * du / (dt * 1e6), 1)
        else:
            s["cpu_pct"] = None
        if usage is not None:
            self.last_cpu = (usage, now)

        s.update(scrape_server())
        for k, q in QUERIES.items():
            s[k] = prom(q)
        s["conntrack"] = conntrack_count()
        s["state"] = docker_state(self.cid)
        return s


def fmt_bytes(n):
    if n is None:
        return "n/a"
    return f"{n / 2**20:,.1f} MiB"


def per_conn(value, idle, conns):
    if value is None or idle is None or not conns:
        return None
    return round((value - idle) / conns)


def cmd_idle(args):
    sampler = Sampler(args.container)
    sampler.sample()  # primes the CPU counter
    time.sleep(STEP)
    s = sampler.sample()
    with open(os.path.join(args.out, "idle.json"), "w") as f:
        json.dump(s, f, indent=2)
    print(f"idle: cgroup {fmt_bytes(s['cg_memory'])}, rss {fmt_bytes(s['process_rss'])}, "
          f"goroutines {s['goroutines']}, fds {s['open_fds']}")


def cmd_run(args):
    with open(os.path.join(args.out, "idle.json")) as f:
        idle = json.load(f)
    sampler = Sampler(args.container)
    sampler.sample()
    start = time.time()
    best, best_at, reached_at, reason = None, start, None, None
    rows = []

    with open(os.path.join(args.out, "samples.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        while True:
            time.sleep(STEP)
            s = sampler.sample()
            rows.append(s)
            w.writerow(s)
            f.flush()

            conns = s["server_conns"] or 0
            print(f"[{int(s['t'] - start):4d}s] conns {conns:>9,.0f}  "
                  f"cgroup {fmt_bytes(s['cg_memory']):>12}  sock {fmt_bytes(s['cg_sock']):>11}  "
                  f"cpu {s['cpu_pct'] or 0:5.1f}%  dial err/15s {s['dial_errors_15s'] or 0:,.0f}  "
                  f"state {s['state']}", flush=True)

            if best is None or conns > best * 1.005:
                best, best_at = conns, time.time()
            if not s["state"].startswith("running"):
                reason = f"server container stopped ({s['state']})"
                break
            target = s["loadgen_target"]
            if target and conns >= target:
                reached_at = reached_at or time.time()
                if time.time() - reached_at >= args.hold:
                    reason = f"target of {target:,.0f} connections reached and held for {args.hold}s"
                    break
            if time.time() - best_at >= args.plateau:
                reason = f"no growth above {best:,.0f} connections for {args.plateau}s"
                break
            if time.time() - start >= args.max:
                reason = f"time limit of {args.max}s reached"
                break

    errors = prom_vector("sum by (reason) (loadgen_dial_errors_total)")
    write_summary(args, idle, rows, reason, errors)


def write_summary(args, idle, rows, reason, errors):
    # Only samples where the server answered and the cgroup still existed.
    live = [r for r in rows if r["server_conns"] and r["cg_memory"] is not None]
    # Use the last sample within 0.5% of the maximum: memory and latency have
    # settled there, while the first sample to hit the maximum is mid-ramp.
    top = max((r["server_conns"] for r in live), default=0)
    peak = [r for r in live if r["server_conns"] >= 0.995 * top][-1] if live else rows[-1]
    conns = peak["server_conns"] or 0
    last = rows[-1]
    err = {dict(k).get("reason", "?"): int(v) for k, v in errors.items() if v}
    window = [r for r in live if r["server_conns"] >= 0.98 * conns]
    cpu = [r["cpu_pct"] for r in window if r["cpu_pct"] is not None]

    summary = {
        "variant": args.variant,
        "stop_reason": reason,
        "duration_s": round(rows[-1]["t"] - rows[0]["t"]),
        "peak_connections": int(conns),
        "loadgen_target": peak["loadgen_target"],
        "at_peak": {k: peak[k] for k in FIELDS if k not in ("t", "state")},
        "idle": {k: idle.get(k) for k in ("cg_memory", "cg_anon", "cg_sock", "cg_kernel", "process_rss", "goroutines", "open_fds")},
        "bytes_per_connection": {
            "cgroup_total": per_conn(peak["cg_memory"], idle["cg_memory"], conns),
            "cgroup_anon": per_conn(peak["cg_anon"], idle["cg_anon"], conns),
            "kernel_sockets": per_conn(peak["cg_sock"], idle["cg_sock"], conns),
            "kernel_other": per_conn(peak["cg_kernel"], idle.get("cg_kernel"), conns),
            "kernel_slab": per_conn(peak["cg_slab"], idle.get("cg_slab"), conns),
            "process_rss": per_conn(peak["process_rss"], idle["process_rss"], conns),
            "go_heap": per_conn(peak["go_heap_inuse"], idle.get("go_heap_inuse"), conns),
        },
        "cpu_pct_near_peak_avg": round(sum(cpu) / len(cpu), 1) if cpu else None,
        "final_state": last["state"],
        "oom_killed": " true " in f" {last['state']} ",
        "cgroup_memory_peak": max((r["cg_peak"] or 0) for r in rows),
        "dial_errors_by_reason": err,
    }
    with open(os.path.join(args.out, "summary.json"), "w") as f:
        json.dump(summary, f, indent=2)

    b = summary["bytes_per_connection"]
    kb = lambda v: "n/a" if v is None else f"{v / 1024:.1f} KiB"
    num = lambda v: "n/a" if v is None else f"{v:,.0f}"
    lines = [
        f"# {args.variant}",
        "",
        f"Stopped because: {reason}.",
        "",
        "| Metric | Idle | At peak |",
        "| --- | --- | --- |",
        f"| Connections | 0 | {num(conns)} |",
        f"| Container memory (cgroup) | {fmt_bytes(idle['cg_memory'])} | {fmt_bytes(peak['cg_memory'])} |",
        f"| Kernel memory (socket structs, epoll, slab) | {fmt_bytes(idle.get('cg_kernel'))} | {fmt_bytes(peak['cg_kernel'])} |",
        f"| Kernel socket buffers | {fmt_bytes(idle['cg_sock'])} | {fmt_bytes(peak['cg_sock'])} |",
        f"| Process RSS | {fmt_bytes(idle['process_rss'])} | {fmt_bytes(peak['process_rss'])} |",
        f"| Go heap in use | {fmt_bytes(idle.get('go_heap_inuse'))} | {fmt_bytes(peak['go_heap_inuse'])} |",
        f"| Goroutines | {num(idle['goroutines'])} | {num(peak['goroutines'])} |",
        f"| Open file descriptors | {num(idle['open_fds'])} | {num(peak['open_fds'])} |",
        f"| CPU, average near peak | | {summary['cpu_pct_near_peak_avg'] or 'n/a'}% of one core |",
        f"| Echo latency p50 / p99 | | {num(peak['echo_p50_ms'])} ms / {num(peak['echo_p99_ms'])} ms |",
        "",
        "Memory per connection, (peak - idle) / connections:",
        "",
        "| Source | Per connection |",
        "| --- | --- |",
        f"| Container total (cgroup) | {kb(b['cgroup_total'])} |",
        f"| Anonymous memory | {kb(b['cgroup_anon'])} |",
        f"| Kernel memory (socket structs, epoll, slab) | {kb(b['kernel_other'])} |",
        f"| of which slab objects | {kb(b['kernel_slab'])} |",
        f"| Kernel socket buffers | {kb(b['kernel_sockets'])} |",
        f"| Process RSS | {kb(b['process_rss'])} |",
        f"| Go heap | {kb(b['go_heap'])} |",
        "",
        f"Final container state: `{last['state']}` (status, OOM-killed, exit code). "
        f"Highest cgroup memory during the run: {fmt_bytes(summary['cgroup_memory_peak'])}.",
        "",
        "Dial errors by reason: " + (", ".join(f"{k} {v:,}" for k, v in sorted(err.items())) or "none") + ".",
        "",
    ]
    with open(os.path.join(args.out, "summary.md"), "w") as f:
        f.write("\n".join(lines))
    print("\n".join(lines))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("mode", choices=["idle", "run"])
    p.add_argument("--container", required=True, help="full container ID of the server")
    p.add_argument("--out", required=True)
    p.add_argument("--variant", default="")
    p.add_argument("--hold", type=int, default=60, help="seconds to hold after reaching the target")
    p.add_argument("--plateau", type=int, default=90, help="stop after this many seconds without growth")
    p.add_argument("--max", type=int, default=1800, help="hard time limit in seconds")
    args = p.parse_args()
    {"idle": cmd_idle, "run": cmd_run}[args.mode](args)


if __name__ == "__main__":
    sys.exit(main())
