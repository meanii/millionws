# Optimization night, 2026-09-29

Follow-up to [2026-09-28-comparison.md](2026-09-28-comparison.md). Same 1 CPU /
1 GiB capped server unless the run says otherwise. Baseline for every
comparison: `nbio-tuned` median — 190,894 conns, 4.91 KiB total (3.83 kernel
slab + 1.08 Go anon), ~99% of one core near peak, echo p99 ~93 ms.

| Run dir | Change | Peak | KiB total / Go / kernel | CPU¹ | p99 | Stop |
| --- | --- | --- | --- | --- | --- | --- |
| `nbio-profile` | `+ -pprof` (tuned behavior), heap+CPU profiles at 190k | 190,365 | 4.94 / 1.03 / 3.84 | 92% | 179 | plateau, up |
| `nbio-nokeepalive` | `-keepalive=0s` | 203,648 | 4.62 / 0.72 / 3.83 | 88% | 153 | plateau, up |
| `nbio-nokeepalive-2` | repeat | 203,716 | 4.60 / 0.71 / 3.83 | 96% | 95 | plateau, up |
| `nbio-tuned-2` | `SERVER_CPUS=2` | 191,560 | 4.92 / 1.01 / 3.84 | 94% | 166 | plateau, up |
| `nbio-tuned-3` | `SERVER_CPUS=4` | 189,941 | 4.96 / 1.04 / 3.84 | 174% | 188 | plateau, up |
| `nbio-tuned-4` | `SERVER_MEM=512m` | 95,887 | 4.88 / 0.96 / 3.83 | 100% | 98 | plateau, up |
| `nbio-gogc50` | `GOGC=50` | 194,448 | 4.85 / 0.96 / 3.83 | 84% | 338 | plateau, up |
| `nbio-gogc200` | `GOGC=200` | 184,087 | 5.12 / 1.19 / 3.84 | 81% | 367 | plateau, up |
| `nbio-pollers1` | `-pollers=1` (default NumCPU/4 = 3) | 191,962 | 4.91 / 1.00 / 3.83 | 94% | 156 | plateau, up |
| `nbio-tuned-5` | dial burst 5,000/s, target 100k | 100,000 | 5.29 / 1.39 / 3.83 | 12% | 3 | held 60 s |
| `nbio-tuned-6` | active: 1 KiB every 1 s, 50k conns | 50,000 | 10.90 / 3.15 heap + 3.0 KiB sock bufs | 100% | 4,249 | held 60 s |
| `nbio-tuned-7` | soak, 600 s plateau window | 190,890 | 4.94 / 1.01 / 3.84 | 82% | 199 | plateau 600 s, up |

¹ CPU is percent of one core (cgroup CPU time / wall time); 4 CPUs read up to 400%.

## What each run says

- **Keepalive off wins** (`-keepalive` flag, default 120 s preserves tuned):
  Go anon 1,101 → 802 B (−299 B/conn, matching the predicted ~160–300 B of
  `time.newTimer` + `setDeadline`), peak +6.7% (203,682 median of 2, ±68).
  Kernel byte-identical. Cost: no dead-peer detection — fine for the bench,
  production needs the shared-sweep replacement from the roadmap.
- **Peak is memory-bound, not CPU-bound**: 2 and 4 CPUs give the same peak
  and per-conn numbers (4.92/4.96 KiB). Total CPU burn rises with cores
  while p99 worsens — for idle conns, 1 CPU is the most efficient; size EC2
  for memory (2 vCPU for margin, not 8).
- **Linear scaling confirmed**: 512 MiB holds 95,887 (2× = 191,774 vs
  190,894 at 1 GiB, 0.5% off). 1M projection stands: 1M × 4.91 KiB ≈ 4.8 GiB
  → ~5.3 GiB limit at 90% guard → 8 GiB box minimum.
- **GOGC**: 50 buys +1.9% peak and less CPU but 3.6× p99 (338 ms); 200 loses
  3.5% peak (dead heap trips the guard early) with lower CPU. Default 100 is
  the sweet spot for latency.
- **Single poller changes nothing** at peak (pollers hold no per-conn
  state); idle fds drop 15 → 11 (fewer epoll/event fds), as predicted.
- **Burst**: 5,000 dials/s reaches 100k in 20 s with zero dial errors —
  safe ramp rate for cloud runs (1M in ~4 min).
- **Active traffic is a different regime**: at 1 KiB/s per conn the 1-CPU
  server saturates near ~40k conns; socket buffers (not slab) dominate
  growth (~3 KiB/conn and climbing), p99 hits 4.2 s, goroutines 1,890
  (vs ~20 idle), and even `/metrics` scrapes time out. Idle numbers apply
  to mostly-idle conns only.
- **Soak**: 195 flat-top samples over 602 s, cgroup 924.0 → 925.6 MiB
  (+1.6 MiB drift = noise), zero dips below 189k, no OOM. No leak.
  First `timeout` dial errors seen (14,604 of 540k) — SYN drops under a
  10-minute dial storm while the host sat at load 44, not server backlog.
- **Loadgen client cost** (`loadgen-mem.txt` in the soak dir): 6.57–6.64
  KiB/conn, all 5 replicas within 1%. A 250k-conn client needs ~1.7 GiB.
- **fd accounting**: `open_fds − conns` is ~12 pre-guard (idle 11–15 + 1)
  and ~50 during the 503 storm (rejected handshakes briefly hold fds).
  Stable within each phase — offset, not leak.

## Heap at 190k (`nbio-profile/heap-190k-top.txt`)

`go tool pprof -top` on the plateau profile (154.5 MB in use, run against
the server binary copied out of the container):

| Source | MB | B/conn |
| --- | --- | --- |
| `nbio.dupStdConn` | 37.0 | 204 |
| `websocket.NewServerConn` (struct) | 35.5 | 196 |
| `time.newTimer` (keepalive deadlines) | 21.9 | 120 |
| `net.sockaddrToTCP` + `syscall.anyToSockaddr` | 25.0 | 138 |
| `nbio.Conn.setDeadline` (flat) | 7.5 | 41 |

Timer-related total ≈ 160 B/conn — the `-keepalive=0s` runs then removed
~300 B/conn of Go anon, consistent (deadline resets also churn garbage).
`dupStdConn` + struct + addresses (~530 B) are nbio-structural: only a fork
or upstream change moves those.

## Method notes

- One bench at a time: launches go through `flock -n /tmp/opencode/bench.lock`
  after duplicate `run.sh` processes fought over one compose stack (their
  `record.py` twins sampled the same server into two result dirs; the
  orphan partials were deleted, the coherent survivor kept).
- A saturated server stops answering `/metrics` (3 s scrape timeout), which
  `record.py` logs as `server_conns = 0`. Those rows stay in `samples.csv`;
  the peak logic ignores them. Frequent zeros + 100% CPU = saturated, not dead.
- Prometheus keeps last values after death; the direct `/metrics` read is
  what makes peaks trustworthy.
