# Virginia: 1,000,008 connections held for 75 minutes with nothing touching the server (all times IST)

The clean hold that the earlier runs lacked. One server and three clients in `us-east-1`; after the ramp, the only things that touched the server for 75 minutes were Prometheus scrapes and a once-a-minute poll of Prometheus from my machine. No SSH to the server, no profiling, no snapshots, until the hold was over.

Result: **1,000,008 connections held from 13:10:20 to at least 14:44 (about 94 minutes; the 75 minutes are the passive window), 0 rejections, 0 failed upgrades, 0 OOM kills, 0 restarts, and no new disconnects after the ramp.** Container memory was flat.

Evidence: [evidence/](evidence/). The large files (a video of the last ten minutes and the Prometheus database) are in the release `evidence-validation-2026-09-30`, see [evidence/video/README.md](evidence/video/README.md).

## Setup

| | |
| --- | --- |
| Region | `us-east-1`, one AZ |
| Commit | `73a50a4` (`~/GIT_SHA` in the snapshots); server and loadgen code unchanged from `703e1e1` |
| Server | `m7i-flex.large` (2 vCPU, 8 GiB), on-demand, container limit 6 GiB, `-ports=8080-8095 -keepalive=0s -maxload=1100000`, host networking |
| Clients | 3 x `c7i-flex.large`, 4 loadgen replicas each x 83,334, one 32-byte message per connection every 30 s; target 1,000,008 (3 x 333,336), so the 1,000,000 is exceeded and the server's cap is not reached |
| Timezone | hosts `Asia/Kolkata`; Prometheus and the Grafana screenshots are in IST |
| Duration | apply 13:06:26, 1,000,008 at 13:10:20, passive polling until 14:25:50, final light capture 14:26, destroyed 14:47 (the load ran on, so Prometheus has data until 14:44) |
| Cost | about $0.65: 1 h 40 min at about $0.385 per hour, estimated from list prices |

## Results

From [evidence/logs/hold_polling_1min.csv](evidence/logs/hold_polling_1min.csv) (70 readings, 13:10:20 to 14:24:43), the 10 s sampler CSVs in [evidence/hosts](evidence/hosts/), the final snapshot and the Prometheus export.

| Measurement | Value |
| --- | --- |
| Connections, server | 1,000,008 in every one of the 70 readings (minimum equals maximum) |
| Rejections (503), failed upgrades | 0, 0 |
| Disconnects | 44 in total, all during the ramp; none after it |
| OOM kills | none (`dmesg` empty; `restarts=0`, `oomkilled=false`) |
| Echo latency p99 (1 min windows, at the loadgen) | 393 to 400 ms, median 395 ms |
| Message rate | 33,333 per second (1,000,008 / 30 s) |
| Container memory (cgroup), median per 10 minutes | 5,168 (13:20), 5,172, 5,172, 5,172, 5,172, 5,172, 5,173 MiB (14:20); last sample 5,174; range 5,168 to 5,178 from 13:20 on |
| Memory per connection (all-in) | 5.3 KiB |
| Host memory in use (`free`, sampler) | 5,243 MiB at the start of the hold, 5,454 at the end |
| Server CPU (`docker stats`, one core = 100%) | 51.8% at 14:26 |
| ENA `conntrack_allowance_exceeded` | 0 throughout; `available` 76,957 |
| ENA `pps_allowance_exceeded` | grew from 0 to 17,445 during the hold, about 4 per second, on the server only |
| **Kernel connection-tracking table** | **1,000,030 entries of 1,048,576 (95.4%)**, 244 MiB; 0 `table full` messages |

The memory figure is the leak check: it changed by 1 MiB between 13:30 and 14:20, in 55 minutes, at 1M connections. That rules out a leak large enough to matter at this timescale; it does not rule out a slower one.

Two more things worth stating. The kernel's tracking table was 95% full for the whole hold. The run stayed under the cap because 1,000,008 < 1,048,576, and would have dropped flows at 1.05M, which is what happened in the [Mumbai run](../2026-09-30-mumbai-validation/README.md). And the server's packet-rate allowance counter kept rising (17,445 counted events), so the instance is at its packet-rate limit at this message rate; the effect on latency, if any, was not separated from the loadgen's own.

## What this run does not show

- One hold of 75 minutes (94 in the Prometheus data), at one message per connection per 30 s. A busier load, a longer hold, or a different region was not tested.
- The video shows the last ten minutes only (14:16 to 14:26), and starts after the ramp.
- One unexplained item: the Grafana panel "GC duration quantiles" shows a spike to about 30 ms near 14:40, after the passive window. I did not look into it.
- After the 75 minutes I read the server's conntrack table over SSH (a read-only `cat`) and stopped its Prometheus container to copy the database, so the last minutes of data are not undisturbed.

## How the evidence was captured

`hold_polling_1min.csv` and the final capture come from `/tmp/runB.sh` (kept out of the repo): a loop that queried Prometheus once a minute, and after 75 minutes took the safe snapshot script on the four hosts, copied the sampler CSVs (written every 10 s by `scripts/evidence/sampler.sh` from boot), and read `dmesg`, the container status and `/metrics`. The Prometheus export, screenshots and the database copy were taken afterwards.
