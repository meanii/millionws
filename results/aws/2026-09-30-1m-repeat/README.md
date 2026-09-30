# AWS run, 2026-09-30: repeat of the 1M run, with evidence captured

A second 1,000,000-connection run at the same commit and configuration as the [first](../2026-09-30-1m/README.md), made because the first run's Prometheus data and screenshots were lost when its stack was destroyed. This run was instrumented: Prometheus history, Grafana screenshots, and system snapshots from all four hosts are in [../evidence](../evidence/README.md).

Result: **999,996 connections held on the server for 18 minutes** (03:42:50 to 04:00:40 UTC in the exported series, 04:01 in a last direct sample), 0 rejections, 2 failed handshakes, no connection-tracking drops. The target was 1,000,000 this time (3 clients x 333,332), which is under the server's `MaxLoad` of 1,000,000, so nothing was left dialing against the cap.

## Setup

Same as the first run except the target and the runtime limit:

| | |
| --- | --- |
| Commit | `cecfc2487c9c0a23e612aff90301dbd91ca33c40`; the server and loadgen code is unchanged since `07cf492` (`hosts/*_snapshot.txt` shows the SHA) |
| Server | `m7i-flex.large` (2 vCPU, 8 GiB), on-demand, container limit 6 GiB, `-ports=8080-8095 -keepalive=0s`, host networking |
| Clients | 3 x `c7i-flex.large` (2 vCPU, 4 GiB), on-demand, 4 loadgen replicas each x 83,333 connections, one 32-byte message per connection every 30 s |
| Kernel | 6.12.110-135.201.amzn2023.x86_64 |
| Network | open security group, filtering in the subnet network ACL ([rules](../evidence/network/nacl_rules.txt)) |
| Command | `tofu apply -var my_ip=<ip>/32 -var key_name=millionws-bench -var git_ref=cecfc24... -var use_spot=false -var client_count=3 -var conns_per_client=333332 -var max_runtime_minutes=90` |
| Timeline (UTC) | instances launched 03:39:16 and terminated 04:01:44 (CloudTrail: 22 min 28 s), server listening 03:41:03, 999,996 at 03:42:50, last export 04:00:49 |
| Cost | about $0.15: the fleet ran 22 min 28 s at about $0.39 per hour on-demand (estimated from list prices: 0.0958 + 3 x 0.0848 plus volumes and IPv4) |

## Results

Values come from `prometheus/prometheus_range.json` (10 s steps, 03:39:30 to 04:00:49) unless another file is named.

| Measurement | Value |
| --- | --- |
| Connections held, server / all loadgens | 999,996 to 999,999 / 999,994 to 999,996 over the 1,070 s hold |
| Rejections (503), failed upgrades, disconnects | 0, 2, 48 (48 on both sides) |
| Dial errors | 222,610 `refused` (before the server listened), 2 `timeout` |
| Established TCP per client (`hosts/client*_snapshot.txt`) | 333,337 each (`ss -s`) |
| Server established TCP (`hosts/server_snapshot.txt`, 03:54) | 999,998 |
| Message rate received / sent per second (median over the hold) | 33,330 / 33,333 (1,000,000 / 30 s = 33,333) |
| Echo latency p50 / p99, loadgen, 1 minute windows (median over the hold) | 2.8 ms / 389 ms (p99 range 388 to 391 ms) |
| Server open file descriptors, goroutines | 1,000,021, 30 |
| Server CPU (`docker stats`, percent of one core, 2 vCPU host) | 63.9% at 03:51 (`hosts/server_snapshot.txt`) |
| Clients CPU / memory | loadgen containers 5 to 6% CPU each, 475 MiB each; client total 2,053 MiB used of 3,814 |
| ENA `conntrack_allowance_exceeded` / `available` | 0 / 76,957 on every host, unchanged |
| ENA `bw_in`, `bw_out` allowances exceeded | 0 |
| ENA `pps_allowance_exceeded` | server 10,966 at 03:54 and 16,534 at 04:01; clients 47, 1,364 and 0 |

### Memory on the server

| Sample (UTC) | cgroup memory | process RSS | Source |
| --- | --- | --- | --- |
| 03:43 (hold start) | not sampled | 1,111 MB | Prometheus |
| 03:47 | not sampled | 1,394 MB | Prometheus |
| 03:51 | 5,086 MiB (`docker stats` 4.968 GiB) | 1,410 MB | `hosts/server_snapshot.txt` |
| 03:56 | 5,162 MiB | 1,488 MB | `hosts/server_memory_samples_TRANSCRIBED.txt` |
| 03:58 | 5,165 MiB | 1,490 MB | same |
| 04:01 | 5,168 MiB | 1,494 MB | `hosts/server_last_sample_04-01Z.txt` |

At 04:01, 5,168 MiB over 999,996 connections is **5.29 KiB per connection all-in**. Of that, the kernel slab was 3,739 MiB (3.83 KiB per connection, identical to the local benchmark's kernel part) and anonymous memory 1,413 MiB (1.45 KiB per connection), from `memory.stat` read at 03:56 to 03:58 (`hosts/server_memory_samples_TRANSCRIBED.txt`).

The Go heap in use oscillates between about 740 and 1,240 MB (the GC sawtooth in the screenshots); the Go memory limit stayed at 1.75 GB.

## What this run shows and does not show

- **The 1M result repeats.** Same commit, same instance types: 999,996 held, no rejections. The first run's 999,999 is corroborated by an instrumented one with data and screenshots.
- **Memory grew slowly during the hold.** RSS rose 27% in the first 8 minutes of the hold (1,111 MB at 03:43 to 1,410 MB at 03:51) and the cgroup total by 76 MiB between 03:51 and 03:56, then by 6 MiB in the next 5 minutes. The slab share was constant. That is consistent with the heap filling to its GC target, but 18 minutes is too short to rule out a slow leak. The local benchmark's 10 minute soak at 190,000 showed none.
- **The instance is at its packet-rate allowance under this load.** `pps_allowance_exceeded` on the server keeps rising during the steady hold (10,966 at 03:54, 16,534 at 04:01, about 14 per second). At about 33,000 messages per second each way that is at least 66,000 packets per second before acknowledgements. The count is small against that (about 0.02%), so the effect on throughput is small, but it means this instance size is close to its packet limit and it may contribute to the echo p99 of about 390 ms. I did not test that, and the loadgen's own 2 vCPU clients running four processes each also add queueing.
- **Two failed upgrades and two dial timeouts** are in the counters; I did not check when they happened or investigate them. The first 1M run recorded 0 upgrade errors and 2,195 dial timeouts at the time of its sample, so the two runs are not directly comparable on this.
- **Not tested:** anything above 1,000,000 (the server's `MaxLoad`), a busier message rate, runs longer than 18 minutes, and other instance types.
- **The screenshots are Grafana's own dashboards** from the repo (`MillionWS local bench` and `MillionWS`); the range is fixed to 03:39:30 to 03:59:32 and 04:00:18. The second one shows all Prometheus jobs, including the loadgens, so its memory panels show several series.

## How the evidence was captured

- Prometheus and Grafana ran on the server as in the stack; range queries were exported over HTTP from the operator's IP, screenshots taken with headless Chromium (Playwright) against the live Grafana.
- System snapshots (`hosts/`) come from one script run over SSH on each host; the script prints `uname`, `free`, `ss -s`, the container memory, and the ENA counters.
- The AWS-side records (`aws/cloudtrail_timeline.csv`, `aws/cloudwatch/`) come from CloudTrail and CloudWatch and do not depend on the instances.

## Mistakes while capturing

- The first headless-browser attempts produced a blank result and then Grafana's "failed to load its application files" page; the cause was the browser's missing locale (`Intl.NumberFormat`), fixed by setting `en-US`. The failed screenshot was not kept.
- My first host-snapshot loop passed an empty host argument because of zsh word splitting; those files were regenerated.
- My first read of the RSS series as a steady state was wrong: the export showed it rising over the hold. The table above uses the later samples.
