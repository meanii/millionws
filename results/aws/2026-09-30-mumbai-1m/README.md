# AWS Mumbai (ap-south-1), 1,000,000 connections, all times IST (UTC+05:30)

One server and three clients in Mumbai, 999,996 connections, recorded with a video, a terminal recording, Grafana screenshots, the raw Prometheus data, and kernel logs. **The server held 1M for 34 minutes at a stretch, and was OOM-killed three times, each within 14 seconds of a 30-second CPU profile starting (the third one on purpose, and the only one shown by itself to be the cause).** The 1M number is real, and so is a limit that the earlier runs did not show: at 1M connections a 6 GiB container survives only about 7 to 12 seconds of a stalled read path.

Evidence index and how each file was made: [evidence/](evidence/). Earlier runs: [Virginia, 999,999](../2026-09-30-1m/README.md) and [Virginia repeat, 999,996 for 18 minutes](../2026-09-30-1m-repeat/README.md).

## Setup

| | |
| --- | --- |
| Region / AZ | `ap-south-1`, one AZ, private IPs between instances |
| Commit | `4bbfa7b807a81df1d6640fcbbd11aab5ad77af36` (`~/GIT_SHA` on each host); server and loadgen code unchanged since `07cf492` except that the server ran with `-pprof` |
| Server | `m7i-flex.large` (2 vCPU, 8 GiB), on-demand, container limit 6 GiB, `-ports=8080-8095 -keepalive=0s -pprof`, host networking |
| Clients | 3 x `c7i-flex.large` (2 vCPU, 4 GiB), on-demand, 4 loadgen replicas each x 83,333 connections, one 32-byte message per connection every 30 s |
| Kernel | 6.12.110-135.201.amzn2023.x86_64; timezone `Asia/Kolkata` on every host and container |
| Network | open security group, filtering in the subnet network ACL, as in the [runbook](../../../docs/aws-runbook.md#security-group-connection-tracking-and-the-network-design-that-follows-from-it) |
| Command | `tofu apply -var region=ap-south-1 -var my_ip=<ip>/32 -var key_name=millionws-bench -var git_ref=4bbfa7b... -var use_spot=false -var client_count=3 -var conns_per_client=333332 -var max_runtime_minutes=90` |
| Run | instances launched 10:22:58, terminated 11:41:16 (CloudTrail): 1 h 18 min 18 s |
| Cost | about $0.51: the fleet at $0.1008 (m7i-flex.large, Mumbai) + 3 x $0.0848 (c7i-flex.large) per hour, plus volumes and IPv4, for 1.3 hours (estimated from list prices, not a bill) |

Before the run, Mumbai needed two things the other region already had: the EC2 key pair (imported from the same public key) and a vCPU quota of 8 instead of 5 (requested at 10:17, approved within minutes).

## Timeline (IST)

| Time | Event | Source |
| --- | --- | --- |
| 10:22:58 | four instances launched | CloudTrail |
| 10:24:59 | server process started | server log |
| 10:25:07 | ramp visible in the terminal recording: 104,597 connections one second in, about 999k after 80 s | `terminal/` |
| 10:26:35 | first 999,000+ connections (999,996 by 10:27:01) | Prometheus |
| 10:31:04 | my collection script requests heap and goroutine profiles, then a 30 s CPU profile | timestamp inside the pprof file |
| 10:31:11 | the server's memory guard trips at 5,530 MiB of 6,144 | server log |
| **10:31:18** | **OOM kill 1**; all 1M connections dropped | `kernel/dmesg_oom_kills_3.txt` |
| 10:31:28 | Docker restarts the server; the loadgens reconnect | server log |
| 10:33:35 | back at 999,000+ (2 min 17 s after the kill) | Prometheus |
| 11:07:38 | the same collection again: heap profile timestamp | pprof file |
| 11:07:43 | guard trips at 5,564 MiB | server log |
| **11:07:51** | **OOM kill 2** | dmesg |
| 11:10:10 | back at 999,000+ (2 min 19 s) | Prometheus |
| 11:13 to 11:24 | one-action-at-a-time tests, no crash (see below) | `experiments/` |
| 11:33:39 | on purpose: a 30 s CPU profile alone | `experiments/repro_cpu30s_1133IST.log` |
| **11:33:53** | **OOM kill 3**, 14 s after the profile started | dmesg |
| 11:36:10 | back at 999,000+ (2 min 17 s) | Prometheus |
| 11:41:16 | terminated | CloudTrail |

Continuous periods at 999,000+ connections: 10:26:35 to 10:31:35 (5 min), **10:33:35 to 11:08:10 (34 min 35 s)**, 11:10:10 to 11:34:10 (24 min), 11:36:10 to the end (4 min 25 s). Prometheus samples at 5 s, so the edges are only accurate to that.

Charts: [overview](evidence/charts/timeline_overview_IST.png) and [the third kill at 1 s resolution](evidence/charts/third_kill_1hz_IST.png). Video: [evidence/video](evidence/video/) (Grafana, 10:25 to 10:37, covering the ramp, kill 1 and the recovery). Terminal recording: [evidence/terminal](evidence/terminal/) (`.cast` for `asciinema play`, plus a GIF at 8x).

## Results while holding 1M

Settled window 11:12 to 11:20 IST (after the second recovery, before my tests), from `prometheus/` and `hosts/`:

| Measurement | Value |
| --- | --- |
| Connections, server / loadgens | 999,996 to 999,997 / 999,996 |
| Rejections (503 from the memory guard), failed upgrades | 0, 0 for the whole run |
| Disconnects | 3,000,203 in total: three kills x about 1,000,000, plus about 200 others over 75 minutes |
| Dial errors, whole run | 244,840 `refused` (before the server listened), 21,895 `timeout` and 7,330 `reset` (all during the three re-ramps) |
| Message rate received / sent per second | 33,326 / 33,333 (1,000,000 / 30 s = 33,333) |
| Echo latency p50 / p99 (30 s windows, at the loadgen) | 3.5 ms / 399 ms |
| Server memory (cgroup) | 5,155 to 5,224 MiB of 6,144, at 999,997 connections: **5.3 KiB per connection all-in** |
| of which kernel slab, Go heap (anon) | 3,750 MiB (3.84 KiB per connection), 1,472 MiB (1.51 KiB per connection) at 11:33:30 (`kernel/memwatch_1hz_...csv`) |
| Server process RSS | 1.26 to 1.47 GB |
| Server CPU | 47% average of the two vCPUs in steady 5 minute windows, 57% in the windows containing a ramp (CloudWatch) |
| Client CPU / memory | 22 to 23% CPU (CloudWatch); about 2.3 GiB of 3.8 GiB used (`free`, 2,329 to 2,370 MiB), each holding 333,336 connections |
| Open file descriptors, goroutines | 1,000,021, 29 |
| ENA connection-tracking counters | `conntrack_allowance_exceeded` 0, `available` 76,955 to 76,957 throughout |
| ENA `pps_allowance_exceeded` | server 0 throughout; clients up to 10,571 (client0), 0 (client1), 597 (client2) |

Unlike the Virginia repeat run, the server's packet-rate allowance stayed at 0 here. The Virginia server hit it under the same message rate, so I do not know why the Mumbai one did not; I did not investigate.

`cpu_pct` in the 10 s sampler CSVs ignores softirq and steal time (a bug in the sampler, fixed in `scripts/evidence/sampler.sh` after the run), so it reads 10 to 17% and should not be used. CloudWatch's numbers above are AWS's own. They average five minutes, so short peaks are hidden.

## The three OOM kills

**What the kernel says.** The container was at its 6 GiB limit each time. The memory-cgroup report at the kill (`kernel/dmesg_oom_kills_3.txt`) shows socket buffers at 1.60 GB in all three (1,603,567,616 / 1,605,414,912 / 1,601,814,528 bytes), the kernel slab at 3.92 GB, and the Go heap at about 0.91 GB after the garbage collector had shrunk it from 1.47 GB. Before each kill, socket memory had been about 0.

**The 1 s trace of kill 3** ([chart](evidence/charts/third_kill_1hz_IST.png), [csv](evidence/kernel/memwatch_1hz_30s-cpu-profile-crash_1133IST.csv)): the profile started at 11:33:39. At 11:33:42 socket-buffer memory started climbing by about 120 MiB per second, from 90 to 1,426 MiB by 11:33:53, while the Go heap was squeezed from 1,472 to 891 MiB (the Go memory limit reacting). The container reached 6,069 MiB, and the process was killed at 11:33:53.

Reading: while the profile runs, the server stops draining its sockets. The loadgens keep sending 33,333 messages per second, and each unread message is charged to the container at about 3.7 KiB (roughly one 4 KiB page), which is 120 to 130 MiB per second. From 5,224 MiB, the 920 MiB below the limit lasts about 7 seconds at that rate, and the heap shrinking freed another 580 MiB (about 5 seconds), so the observed 11 seconds fits. At 1M connections a 6 GiB container therefore tolerates a read stall of roughly 7 to 12 seconds. The memory guard cannot help: it only refuses new connections, and this growth is inside existing ones.

**What is established and what is not.**

- Established: kill 3 was caused by the 30 s CPU profile, because it was started alone at a steady 1M and the server died 14 s later. Kills 1 and 2 had the same shape: each began 13 to 14 seconds after my collection script requested profiles (the heap profile timestamps are 10:31:04 and 11:07:38, and the script then requested a 30 s CPU profile), and the 10:31 CPU profile file is timestamped 10:31:29, after the restart, because my SSH helper retries failed commands.
- Not shown directly: that kills 1 and 2 were caused by the CPU profile and not by something else in the same script. Each of the script's other parts passed on its own (below), but I did not replay the script's exact sequence: my "replay" at 11:25 skipped the pprof branch because of a scripting mistake, and it ran without a crash (its snapshot files are named `..._replay-WITHOUT-pprof.txt`).
- Not known: why a CPU profile stalls the read path. The 10 s profile at 11:21:29 also stalled it (echo rate fell to 8,076 per second and p99 rose to 12.9 s, container memory to 5,518 MiB) but ended before the limit. I did not investigate the mechanism.

**One action at a time, at a steady 1M** (11:13 to 11:24, [log](evidence/experiments/bisect_actions_1113-1124IST.log)). None dropped the connection count:

| Action | Result |
| --- | --- |
| snapshot on the server only | no drop |
| snapshot on the three clients only | no drop |
| snapshot on all four hosts at once | no drop |
| pprof heap and goroutine profiles | no drop |
| pprof CPU profile, 10 s | server stalled about 10 s (echo p99 12.9 s), no drop |
| `ss -tin state established \| head -25` | no drop |

`docker stats`, `docker logs`, `ethtool` and the cgroup reads also ran inside the snapshots. The 1 Hz memory logger I meant to run during these tests never started (my `pkill -f memwatch.sh` matched and killed its own SSH shell), so these tests rest on the connection counts and the 10 s sampler. The 1 Hz data is from the 11:33 test.

## Heap profile at 1M connections

`pprof/heap_1107IST_...` (11:07:38, 26 goroutines): 637 MB in use. `nbio.dupStdConn` 200 MB (31%), `websocket.newConn` 155 MB (24%), `net.sockaddrToTCP` 87 MB (14%), `syscall.anyToSockaddr` 54 MB (8%), the accept path 60 MB (9%). This is the same pattern as the local heap profile at 190,000 (about 0.64 KiB per connection in use). Read with `go tool pprof -top -sample_index=inuse_space <file>`.

## What this run says

1. **1M connections work on this instance:** 999,996 held for 34 minutes 35 seconds at a stretch, with 47% of the CPU and 5.3 KiB per connection, in Mumbai as in Virginia.
2. **The 6 GiB container has too little headroom for 1M.** At 84% of the limit, any stall of the read path longer than about 7 to 12 seconds kills the process and all connections; the recovery took 2 min 17 s to 2 min 19 s each time (Docker restart plus the clients redialing at the loadgen's default rate). Options I did not test: a limit above 6 GiB (the machine has 8 GiB, shared with Prometheus and Grafana), a smaller kernel share per connection, or a stall-resistant server.
3. **Do not take a CPU profile of a server at this scale.** `deploy/aws/compose.yml` no longer enables `-pprof`. The heap and goroutine profiles were harmless.
4. **My evidence collection disturbed the system that I was measuring**, at least twice. The collector script now avoids profiles, and `docs/aws-runbook.md` says so.

## Mistakes and limitations of this run

- The scheduled collections at 10:36, 10:45 and 10:57 and the late video and terminal recording never ran. I do not know why: the background jobs were gone when I looked at 11:06. The video covers 10:25 to 10:37 only; the terminal recording 10:25 to 10:36. Prometheus and the samplers cover the whole run.
- The Grafana video recorder crashed on its first start because my script did not install the Playwright package inside the container. I restarted it at about 10:25:40, when the ramp was about half done (about 550,000), so the video starts mid-ramp. The whole ramp is in the terminal recording, from 104,597 connections, and in the Grafana graphs.
- A live-view screen in the recording shows `n/a (busy)` for connections when the server did not answer `/metrics` in 2 seconds.
- Several times my shell helper failed for silly reasons (zsh word-splitting of an options variable; `pkill -f` matching its own command). They wasted time and, in one case, the 1 Hz logger.
- The 10 s sampler's CPU column is wrong (see above); CloudWatch is the source for CPU.
- I did not check what the loadgens experienced during the kills, beyond the dial-error counters.
- One region, one instance type, one run; no soak beyond 35 minutes at a stretch.
