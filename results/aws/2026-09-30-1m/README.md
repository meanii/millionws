# AWS run, 2026-09-30: 999,999 concurrent connections on one m7i-flex.large

A repeat of this run with Prometheus history, Grafana screenshots and host snapshots is in [../2026-09-30-1m-repeat](../2026-09-30-1m-repeat/README.md); the evidence index is in [../evidence](../evidence/README.md).

The 1,000,000-connection run. One server and three clients on EC2. The server held 999,999 connections for the five minutes it was observed after the ramp, with no rejections, no failed upgrades and no connection-tracking drops.

This is the server's own configured limit, not the machine's: `MaxLoad` in `main.go` is 1,000,000 and nbio refuses connections beyond it (`len(engine.conns) >= engine.MaxLoad`). The clients were asked for 1,002,000 (3 x 334,000), so about 2,000 dials were refused for the whole run. See [what the number means](#what-the-number-means).

## Setup

| | |
| --- | --- |
| Region / AZ | us-east-1, one AZ, private IPs between instances |
| Commit | `07cf492b35edf06570d2994a6e50c69868b6d2ba` (recorded in `~/GIT_SHA`); the network ACL and security group changes are OpenTofu only (`75c0cfe`) |
| Server | `m7i-flex.large` (2 vCPU, 8 GiB), on-demand, container limit 6 GiB, `-ports=8080-8095 -keepalive=0s`, host networking |
| Clients | 3 x `c7i-flex.large` (2 vCPU, 4 GiB), on-demand, 4 loadgen replicas each x 83,500 connections, one 32-byte message per connection every 30 s, 1,000 dials per second per replica |
| Kernel | 6.12.110-135.201.amzn2023.x86_64, Amazon Linux 2023 |
| Network | security group open both ways so flows are untracked; subnet NACL filters ([first run](../2026-09-30-250k/README.md#verifying-the-network-rules-from-outside) verified it from outside) |
| Command | `tofu apply -var my_ip=<ip>/32 -var key_name=millionws-bench -var git_ref=07cf492 -var use_spot=false -var client_count=3 -var conns_per_client=334000 -var max_runtime_minutes=120` |
| Timeline (UTC) | apply 03:19, server up about 03:20, 711,012 connections at 03:21:40, 999,999 by 03:22:51, settled sample 03:27:00, destroy 03:27 to 03:29 |
| Cost | about $0.07 for the 10 minutes the fleet ran (on-demand, estimated from list prices) |

## Results

Settled sample at 03:27:00, about 5 minutes after the ramp finished:

| Measurement | Value |
| --- | --- |
| Connections held, server / all loadgens | 999,999 / 999,999 |
| 503 rejections (memory guard), failed upgrades | 0, 0 |
| Disconnects after being established | 46 in about 5 minutes (out of about 1,000,000) |
| ENA `conntrack_allowance_exceeded` | 0 throughout; `conntrack_allowance_available` unchanged at 76,957 |
| bandwidth allowances exceeded | 0 |
| ENA packet-rate allowance (`pps_allowance_exceeded`) | 0 when read at 03:22:43 (mid-ramp); not read again before destroy. The [repeat run](../2026-09-30-1m-repeat/README.md) read 10,966 and 16,534 on the same server type later in its hold, so a later reading here would probably have been above 0. |
| Server container memory (cgroup, all-in) | 5.028 GiB of 6 GiB (83.8%): **5.27 KiB per connection** |
| Server process RSS | 1.47 GB (1.436 KiB per connection); the rest, about 3.84 KiB per connection, is not in the process (kernel memory for sockets and epoll, and cache) |
| Go memory limit the server set | 1.63 GiB |
| Server CPU (`docker stats`, percent of one core; 2 vCPU host) | 62 to 73% during the hold, up to 98% while ramping |
| Open file descriptors, goroutines | 1,000,024, 30 |
| Message rate, received / sent | 33,341 / 33,334 per second (1,000,000 / 30 s = 33,333) |
| Echo latency, p50 / p99 (loadgen, 2 minute window ending 03:27) | 5.7 ms / 406 ms |
| Memory over the hold | 5.015 GiB at 03:24, 5.018 at 03:25, 5.025 at 03:26, 5.028 at 03:27: flat, about 13 MiB in 3 minutes |

Memory per connection at 1M is 5.27 KiB, more than the 4.91 KiB at 190,000 (local) and 5.0 KiB at 250,000 (EC2): the per-connection cost grows a little with the count. The remainder after the process RSS, 3.84 KiB, matches the local benchmark's 3.83 KiB kernel part (this is a subtraction, not a separate kernel measurement).

At the memory guard's 90% threshold (5.4 GiB) this server would hold about 1,074,000 connections, so a 6 GiB container has about 7% headroom above 1M, and an 8 GiB machine with Prometheus and Grafana on it is about at its limit there.

## What the number means

- **The cap is configured.** nbio refuses connections once the engine has `MaxLoad` (1,000,000) open, and `main.go` sets that. The server therefore stopped at 999,999, which is that cap minus one, with memory at 84% of its limit. It was not stopped by memory, CPU, file descriptors or the network. I did not test what the machine holds with a higher `MaxLoad`.
- **About 2,000 dials were refused the whole time.** The clients keep dialing until they hold 334,000 each, so the excess kept getting reset: 1,288,081 `reset` dial errors by 03:27 (about 4,000 per second), on top of 281,580 `refused` errors that did not change after the ramp, so they date from before the server was listening. That churn costs the server CPU and makes the latency figures slightly worse than a run at exactly 1,000,000 target. A cleaner run would ask for 1,000,000 or raise `MaxLoad`.
- **One five-minute hold.** No soak. The local benchmark had a 10 minute soak with no leak; here memory was flat over 3 minutes and I did not watch longer.
- **Idle connections plus a light message rate.** One 32-byte message per connection every 30 seconds, as in the local benchmark. This is not a busy-connection test; the local optimization run showed a server is CPU-bound at about 40,000 connections at 1 KiB/s each.

## Mistakes while running

- My first "steady-state" sample was taken at 03:23:10, about 20 seconds after the ramp finished, not at the 03:25 I intended: the wait used `date -d` in my machine's local timezone instead of UTC, so it returned immediately. I noticed from the timestamp in the output and took the settled sample above. The 03:23 values (for example p99 946 ms) are ramp values and are not used.
- I skipped the planned 500k stage and went to 1M after the 250k run passed. The [250k run](../2026-09-30-250k/README.md) is the only intermediate point.

## Not measured

- Client memory at 83,500 connections per replica (only at 25,000 and 150,000: 6.4 and 5.6 KiB per connection).
- Latency at the server side; the figures are round trips measured at the loadgen on 2 vCPU clients running four processes each, so client queueing is included.
- Behaviour above 1,000,000, or with a different `MaxLoad`.
- The packet-rate allowance after the ramp (see the ENA row above).
- The watchdog Lambda terminating an instance and the on-instance shutdown timer (the stacks were destroyed before either fired).
