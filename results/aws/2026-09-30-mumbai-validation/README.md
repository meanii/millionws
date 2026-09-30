# Mumbai validation run: 500k, 1M, stall tolerance, and the limit above 1M (all times IST)

One server and three clients in Mumbai (`ap-south-1`), 13:02 to 15:05, used to answer four open questions from the earlier runs: what does 500k look like, how long a stall can the server survive at 1M, what happens above 1M, and what limits it. It found a configuration limit that had been sitting just above the earlier 1M runs.

Evidence: [evidence/](evidence/). A companion run, a 75 minute passive hold at 1M in Virginia, is in [../2026-09-30-virginia-hold-75min](../2026-09-30-virginia-hold-75min/README.md).

## Setup

| | |
| --- | --- |
| Region | `ap-south-1`, timezone `Asia/Kolkata` on hosts and containers |
| Commit | `703e1e1a6fd64197acdb401f84d09b7d398e7e83` (`-maxload` flag, stall and add-loadgen scripts); the OpenTofu changes made afterwards do not affect what ran |
| Server | `m7i-flex.large` (2 vCPU, 8 GiB), on-demand, host networking, `-ports=8080-8095 -keepalive=0s -maxload=2000000`; container limit 6 GiB at the start, changed during the run (below) |
| Clients | 3 x `c7i-flex.large` (2 vCPU, 4 GiB), on-demand, 4 loadgen replicas each, more added by `scripts/evidence/add_loadgen.sh`; one 32-byte message per connection every 30 s |
| Kernel | 6.12.110-135.201.amzn2023.x86_64 |
| Network | open security group, filtering in the subnet network ACL, as in the [runbook](../../../docs/aws-runbook.md) |
| Cost | about $0.80: 2 h 3 min at about $0.39 per hour, estimated from list prices |

## What was done, in order

| Time | Step |
| --- | --- |
| 13:02:42 | `tofu apply` with 500,004 connections as the first target (3 x 166,668) |
| 13:08:09 | 500,004 held; held 5 minutes, snapshot |
| 13:13 to 13:16:11 | +166,666 on each client: 1,000,002 held; 4 minutes, snapshot |
| 13:20 to 13:25 | **stall series at a 6,144 MiB container limit**: 5 s freeze survived, 9 s freeze killed the server |
| 13:29 | limit raised live to 6,500 MiB (`docker update`; the server's own guard thresholds still come from the original 6,144 MiB) |
| 13:29 to 13:35 | **stall series at 6,500 MiB**: 9 s survived, 14 s killed |
| 13:38:20 | +100,000 on each client, aimed at 1.3M: **the server stopped accepting new connections at about 1.03M**, and SSH and Prometheus queries stopped answering (below) |
| 14:10 to 14:12 | extra load removed; connection tracking exempted for the server ports; server restarted with a 7 GiB limit and `-maxload=2000000` |
| 14:17 | +100,000 on each client again: **1,300,002 held**, 0 rejections |
| 14:46 | +60,000 on each client: **1,420,239 held**, the server's memory guard rejected the rest |
| 14:57 | stall at 7 GiB after returning to 1M: 14 s killed the server |
| 15:05 | destroyed and verified empty |

## Finding 1: the kernel's connection-tracking table capped the run at 1,048,576 flows

At 13:38:37, about 17 seconds after the extra load started, the server's kernel log began to print `nf_conntrack: table full, dropping packet` (3,843 lines by 14:11; 844 in the console output kept in [evidence/conntrack](evidence/conntrack/)). From then on, new flows to the instance were dropped: my SSH sessions, Prometheus queries (the run script's readings are blank from 13:39) and new client connections. Established connections carried on.

- The cause is Linux netfilter's own tracking table, loaded by Docker, with `nf_conntrack_max = 1,048,576` set by the stack's cloud-init. It is **not** the security-group tracking that stopped the first canary at 76,952 connections (that one is untracked since the security group was opened). Each tracked flow takes a 256-byte entry: 1,047,960 entries were 256 MiB.
- The table stayed near its cap after I removed 300,000 connections from the clients (count 1,047,937 to 1,047,947 with about 1.0M connections), presumably stale entries from the flows dropped while it was full. I did not investigate them. `conntrack -F` emptied it (1,047,978 to 3).
- **The earlier 1M runs were only 4.6% below this cap.** The Virginia run at 1,000,008 read 1,000,030 tracked entries of 1,048,576 at its end.
- Fix: exempt the server ports from tracking with two `iptables -t raw ... -j CT --notrack` rules (server only; now in `user_data_server.sh`). With 1,000,003 connections held, tracked entries were **47**, and 100 to 130 at 1.3M. The rules were applied by hand on this run's server, then the server was restarted; they were not part of the cloud-init that ran. A later small stack (15:14 to 15:20, `t3.small`) confirmed that the cloud-init version creates the same two rules at boot ([evidence](evidence/conntrack/cloud-init_notrack_check_1517IST.txt)).
- What the exemption did **not** change: the container's kernel memory. It was 3,743 MiB with tracking and 3,751 MiB without, at the same 1M (slab 3,731 MiB in both). I said during the run that tracking costs container memory; that was wrong. The container's memory was different between the two runs because the Go heap grew into the larger limit (1,371 MiB at 6 GiB against 1,686 MiB at 7 GiB).

## Finding 2: the stall tolerance is (limit minus usage) divided by about 130 MiB per second

The freeze is `scripts/evidence/stall.sh`: `SIGSTOP` on the server process for N seconds, then `SIGCONT`. The clients keep sending 33,333 messages per second, the kernel keeps receiving them into socket buffers charged to the container, and nothing is read. 1 Hz traces of every test are in [evidence/memwatch](evidence/memwatch/); [chart](evidence/charts/stall_tests_container_memory.png).

| Container limit | Freeze | Container memory before | Headroom | Socket-buffer growth | Result |
| --- | --- | --- | --- | --- | --- |
| 6,144 MiB | 5 s | 5,116 MiB | 1,028 MiB | 131 MiB/s | survived (peak 5,734) |
| 6,144 MiB | 9 s | 5,115 MiB | 1,029 MiB | 130 MiB/s | **killed** |
| 6,500 MiB | 9 s | 5,088 MiB | 1,412 MiB | 132 MiB/s | survived (peak 6,241) |
| 6,500 MiB | 14 s | 5,165 MiB | 1,335 MiB | 131 MiB/s | **killed** |
| 7,168 MiB | 14 s | 5,439 MiB | 1,729 MiB | 130 MiB/s | **killed**, one second before the freeze would have ended |

The growth rate is the same in all five (33,333 messages per second times about 4 KiB), and headroom divided by 130 predicts every outcome to within about a second (7.9 s, 10.8 s, 10.3 s, 13.3 s). Two consequences:

- Each additional GiB of container limit buys about 8 seconds. Surviving a 30 second stall at 1M would need about 3.9 GiB of headroom above the usage, roughly a 9 GiB container, which an 8 GiB instance cannot have.
- A larger limit is partly used up by the Go heap: at 7 GiB the heap grew from about 1.4 to 1.7 GiB, which is why 7 GiB gave 1,729 MiB of headroom and not 2,000.
- A `SIGSTOP` freeze is harsher than a real stall, because it also stops the garbage collector; in the CPU-profile kills of the [first Mumbai run](../2026-09-30-mumbai-1m/README.md) the Go heap shrank by about 580 MiB while the process was starved. The two are comparable within a few seconds, not equal.

After each kill Docker restarted the server and the loadgens redialed: back at 999,000+ connections **3 min 1 s to 3 min 6 s** after the kill (kills at 13:23:54, 13:33:17 and 14:57:44 per the kernel log).

## Finding 3: with 7 GiB and the exemption, the server held 1.3M and stopped at 1.42M

- **1,300,002 connections held from 14:19 for at least 6 minutes**, with 0 rejections and the container at 6.09 GiB (6,236 MiB, 87% of 7,168): 4.9 KiB per connection.
- **At 14:47:42 the memory guard tripped** (`6454 MiB of 7168 MiB used, rejecting new connections`, 90.0%). The server stayed at **1,420,239** connections for the seven minutes of the push, answered further connections with 503 (1,030,719 rejections by 14:54, because the loadgens keep retrying), and was not killed (`restarts=0`, `oomkilled=false`).
- At that point `memory.current` was 6,479 MiB: anon (Go heap) 1,150 MiB, kernel 5,321 MiB (3.83 KiB per connection, the same as at 1M), and the server used 167% of a core (of 2) in `docker stats`, so it was also close to its CPU limit. The clients were at 3,139 of 3,815 MiB (82%).
- Memory per connection is not constant because the Go heap flexes: kernel 3.84 KiB in every state, Go heap about 1.7 KiB at 1M in a 7 GiB container, 1.07 KiB at 1.3M, 0.83 KiB at 1.42M (the garbage collector shrinks it as the limit approaches, which costs CPU).
- So the limit of this instance in this configuration is about **1.42M connections, set by the memory guard at 90% of a 7 GiB container**, on an 8 GiB machine. This is a configuration limit (the guard, the container size), not a measured hardware maximum, and it needs a 7 GiB container that leaves about 0.8 GiB to the host, Prometheus and Grafana (they used 127 MiB and 42 MiB).

## Other measurements

| Measurement | Value |
| --- | --- |
| 500,004 connections | container 2,715 MiB (5.4 KiB per connection), echo p99 352 ms, server 29% of one core |
| 1,000,002 connections | echo p99 386 ms, 33,326 messages per second (500,004: 16,666) |
| Echo latency | about 350 to 400 ms p99 at every step; it did not depend on the connection count, so it is mostly the load generator (100 ms batches, 2 vCPU clients) |
| ENA `conntrack_allowance_exceeded` | 0 on every host for the whole run; `available` never below 76,947 |
| ENA `pps_allowance_exceeded` | server up to 45,232; clients 0, 0 and 701 (as in Virginia, and unlike the first Mumbai run, where it stayed 0) |
| Client memory (`free`, used) | 1,556 MiB at 167k connections per client, 2,387 MiB at 333k, 2,920 MiB at 433k, 3,139 MiB at 473k, of 3,815 MiB |

## What is established, and what is not

- Established: the conntrack table filled and dropped flows at 1,048,576 (kernel log, console output, counts); exempting the ports removed the limit; the stall tolerance formula fits five tests; 1.3M held with 0 rejections; the guard held 1.42M without a kill.
- Not established: why the tracking table stayed full after I removed 300,000 connections; the exact stall thresholds (the series stopped at the first kill, so the 9 s survival at 6,144 MiB and 5 s at 6,500 MiB were not tested); anything about a real, non-frozen stall at 6,500 or 7,168 MiB.
- The 1.3M and 1.42M figures were held for 6 and 7 minutes, not longer.
- Prometheus counters restarted with each server restart, so the `rejected` total in the exported series after 14:57 is 0. The rejection count above comes from the run log.

## Mistakes during the run

- I set the target for the first above-1M attempt without looking at the conntrack limit, and it cost about 30 minutes of the run: the server was unreachable from 13:38 to 14:10, and my scripts' readings for that period are blank.
- My first explanation of the container's memory after the fix was wrong (see Finding 1).
- My first attempt to start the Virginia run while this one was running failed on the account-wide IAM role names; the stack now takes an `iam_name_prefix`.
- Several times my watch filters were silent because of a pipe buffer or a too-narrow pattern, and I had to read the logs directly.
