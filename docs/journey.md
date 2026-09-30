# Journey

A dated log of what was tried, what changed, and why. Newest entries go at the bottom. Commit hashes point to the code at that point.

## December 2025: baseline server and EKS

- 2025-12-04 (`535075e`): first server using gorilla/websocket, one goroutine per connection, with an `/echo` handler.
- 2025-12-08 (`9aeb1f8`, `0e826d0`): added Prometheus metrics, a Grafana dashboard, and a Locust test that connects and sends an echo every 0.5 to 2 seconds.
- 2025-12-10 to 2025-12-16: wrote Terraform for two EKS clusters, one for the server and one for Locust workers, with the cluster autoscaler and the AWS Load Balancer Controller. Nodes are `c6a.xlarge` on demand.
- 2025-12-19 (`c9fa7e9`): first measurement, 5,000 connections at 192 MiB, about 38 KB per connection, with 5,010 goroutines. One goroutine per connection was the obvious cost to remove.

What I learned: two EKS clusters cost money while idle (control plane, NAT gateways, load balancer, minimum node count), and the Kubernetes setup took more time than the server itself. The pod memory limit of 512 MiB in `deploy/millionws/deployment.yaml` would cap a pod at roughly 13,000 connections at 38 KB each, so a single-pod test at scale was not possible with that config anyway.

## January 2026: switch to nbio

- 2026-01-11 (`6e6d347`): replaced gorilla/websocket with nbio. Sockets are registered with epoll and handled by a small goroutine pool, so goroutine count no longer grows with connections. The endpoint moved from `/echo` to `/ws`.
- 2026-01-29 (`ab44a4a`): `-addr` and `-port` flags.

The 5,000-connection test has not been repeated on nbio yet, so there is no before/after number.

## February 2026: single server on Hetzner

- 2026-01-31 to 2026-02-07: moved to one Hetzner Cloud server created by Terraform. cloud-init installs Docker, clones this repository, and runs `deploy/hetzner/compose.yml` (server, Prometheus, Grafana, image renderer). Simpler than EKS and billed by the hour.
- 2026-02-11 (`c42052d`): kernel tuning and file descriptor limits in cloud-init (`fs.file-max`, `somaxconn`, `ip_local_port_range`, `nofile` 200000).
- 2026-02-11: Grafana datasource and dashboard provisioned from files, so a fresh server comes up with the dashboard already loaded.

Left unfinished: a load generator on Hetzner (`376ae9d` started it, the compose file has none).

## September 2026: review and new plan

A review of the repository before continuing found these gaps (full list in [roadmap.md](roadmap.md)):

- The Locust test cannot reach 1M. It is Python with a blocking client, and every user sends a message every 0.5 to 2 seconds, which is about 800,000 messages per second at 1M users.
- One client IP can open about 64,000 connections to one server IP and port, because the source port is 16 bits. 1M connections need either many client IPs or many server ports.
- The file descriptor limit is 200,000 while the server is configured for `MaxLoad: 1000000`, and the container has no `ulimits` of its own.
- The server panics when a WebSocket upgrade fails and prints a line on every disconnect. Both are a problem under load.

Cost check: Hetzner raised cloud prices in June 2026. The comment in `infra/opentofu/hetzner/main.tf` had `ccx33` at €0.077 per hour; the listed price is now €0.2227 per hour. A full 1M run with enough client machines came to an estimated €6 per hour.

Decision: I have $200 of AWS promotional credit, so the load tests move to plain EC2 in one availability zone: one server and four clients, talking over private IPs so data transfer is free. The server listens on 16 ports, which gives each client IP 16 × 64,000 possible connections. The EKS setup stays in the repository as the earlier approach.

## September 2026: local benchmark at 1 CPU and 1 GiB

Before paying for cloud machines I wanted a number for each version of the server, measured the same way. The setup is in [local-benchmark.md](local-benchmark.md): the server in a container capped at 1 CPU and 1 GiB with no swap, five Go load generators each opening up to 60,000 connections, one 32-byte message per connection every 30 seconds, and a recorder that reads the container's cgroup files. Every variant ran three times; the table is in [results/local/2026-09-28-comparison.md](../results/local/2026-09-28-comparison.md).

### The harness had bugs first

- The first recorder took the connection count from Prometheus. Prometheus keeps answering with the last scraped value for a few seconds after a target dies, so right after an OOM kill it reported connections for a container that no longer existed. The recorder now reads the server's `/metrics` itself at the same moment as the cgroup files (`5e91058`).
- The load generator sent the timestamp as 8 raw bytes. The gorilla server echoes every message as a text frame, the client rejected the invalid UTF-8 and closed the connection, and gorilla had no latency numbers. Payloads are decimal text now.
- At 5,000 new connections per second the server died between two samples. The gorilla peak in that run was 25,513; at 1,000 per second, sampled every 2 seconds, it is 39,770.
- Docker on this machine runs rootless. Container cgroups sit under `user.slice`, not `system.slice`, and container-to-container traffic is tracked in Docker's own network namespace. The recorder finds the cgroup from the container's PID and reads conntrack through a helper container.

### Step by step

Medians of three runs:

| Step | Commit | Peak connections | KiB per connection | Result |
| --- | --- | --- | --- | --- |
| gorilla/websocket | `99609ad` | 39,770 | 25.11 | OOM kill |
| nbio, first version | `27b4027` | 193,532 | 5.31 | OOM kill |
| No panic, no log per close | `1b82b39` | 194,014 | 5.36 | OOM kill |
| IPv4 listener | `4e46794` | 200,694 | 5.19 | OOM kill |
| Go memory limit from cgroup | `9a1d737` | 210,730 | 4.93 | OOM kill |
| 503 above 90% of memory | `dadb29f` | 180,842 | 5.39 | stays up |
| Go limit under the 503 threshold | `476f773` | 190,894 | 4.91 | stays up |

gorilla to nbio. gorilla runs one goroutine per connection, each with its own buffers, and used 21.08 KiB of process memory per connection. nbio holds 193,532 connections with fewer than 150 goroutines and 1.35 KiB of process memory each. That is 4.9 times the connections in the same 1 GiB.

The kernel's share. With nbio, 3.96 of the 5.31 KiB per connection is kernel memory: the TCP socket, its inode and file, and the epoll entry. gorilla has the same 4.00 KiB. This part does not depend on the Go code, so it sets the floor: 1 GiB can never hold more than about 270,000 idle TCP connections on this kernel, whatever the server does.

The fixes in `1b82b39` changed nothing measurable, as expected: the benchmark has no failed upgrades and no disconnects before the end.

IPv4 listener. With `"tcp"` on `0.0.0.0`, Go opens a dual-stack `[::]` socket, and every IPv4 client becomes an IPv6 socket in the kernel. Listening on `tcp4` cut kernel memory from 3.96 to 3.83 KiB per connection and raised the peak by 3.7%.

Go memory limit. The heap profile at 120,000 connections showed the live data, but the heap was larger: with the default `GOGC=100`, Go lets the heap grow to twice the live data before collecting, and that garbage was still mapped when the kernel killed the process. A fixed `GOMEMLIMIT` does not fit because the kernel's share grows with every connection. The server now reads `memory.current` once a second and gives Go whatever the kernel leaves. Go memory per connection fell from 1.35 to 1.10 KiB and the peak rose to 210,730. The cost is CPU: the GC ran almost all the time near the limit, CPU went from 37% to 99% of the core, and echo p99 went from 19 ms to 201 ms. The process still died.

Admission guard. An OOM kill closes every connection at once. The server now answers new clients with 503 above 90% of the memory limit. The first version held 180,842 connections and stayed up, fewer than before, because the Go limit was still at 95%: the GC had no reason to collect before the guard started turning clients away.

Final step. With the Go limit at 88%, two points under the guard, garbage is collected first and the guard trips only on live memory. The server held 190,894 connections in all three runs, rejected the rest with 503, and was still running when each run ended. That is 9% fewer than the run that got OOM-killed at 210,730, and I prefer it: at the limit, the earlier version drops 210,000 clients, while this one refuses new ones.

What I did not change: each connection still has its own read-deadline timer and its own copies of its addresses. Together they were about 350 bytes per connection in the heap profile. Replacing the timers with one shared sweep is the next Go-side change to try, but with the kernel at 3.83 KiB it can win at most a few percent.

For the 1M run this gives a sizing estimate: 1,000,000 × 4.91 KiB is about 4.7 GiB, so the server needs a memory limit of about 5.2 GiB with the guard at 90%.

## September 2026, night: optimization round

Twelve more local runs in one night (results in [results/local/2026-09-29-optimization.md](../results/local/2026-09-29-optimization.md)), each testing one idea:

- Heap profile at 190k (`go tool pprof -top` via the new `-pprof` flag): `dupStdConn` 204 B/conn, `NewServerConn` struct 196 B, `time.newTimer` 120 B, addresses 138 B, `setDeadline` 41 B. Timer-related ≈ 160 B/conn.
- `-keepalive=0s` (new flag, default 120 s preserves tuned): Go anon −299 B/conn, peak +6.7% to 203,682 (two runs ±68). Kernel byte-identical. nbio honors 0 as disabled at upgrade and per-message reset; the engine's 120 s floor applies to plain HTTP only, and the upgrader clears the accept-time deadline. Cost: no dead-peer detection.
- CPU scaling: 2 and 4 CPUs hold the same peak and per-conn numbers — the peak is memory-bound. Total CPU burn rises with cores while p99 worsens; 1 CPU is most efficient for idle conns.
- Memory scaling: 512 MiB holds 95,887 (2× within 0.5% of the 1 GiB peak) — linear, so the 1M projection stands.
- GOGC: 50 gives +1.9% peak but 3.6× p99; 200 loses 3.5% (dead heap trips the guard early). Default 100 stays.
- `-pollers=1` (new flag): no change at peak; idle fds 15 → 11 as predicted.
- Burst: 5,000 dials/s reaches 100k in 20 s with zero errors — safe cloud ramp rate.
- Active traffic (1 KiB/s per conn): CPU-bound at ~40k conns, socket buffers dominate (~3 KiB/conn and climbing), p99 4.2 s. Idle numbers apply to idle conns only.
- Soak: 10 min flat at 190,890, +1.6 MiB drift (noise), no OOM. No leak. First `timeout` dial errors (SYN drops under a long storm on a loaded host).
- Loadgen client side: 6.57–6.64 KiB/conn — a 250k-conn client needs ~1.7 GiB.

Method lessons: run one bench at a time under `flock` (duplicate launchers fought over one stack); a saturated server stops answering `/metrics`, which `record.py` logs as `conns 0` (peak logic ignores those rows); `open_fds − conns` ≈ 12 pre-guard and ≈ 50 in the 503 storm (rejected handshakes briefly hold fds) — offset, not leak.

## September 2026, 30th: first AWS attempt and review

The first `tofu apply` on EC2 (`infra/opentofu/aws-ec2`) launched nothing. All four Spot requests were cancelled with `InvalidParameterCombination: instance type is not eligible for Free Tier`: the account was still on the AWS free plan. A second attempt, after rewriting the stack to `aws_instance` with Spot market options, failed the same way at `RunInstances`, so the cause is the account and not the resource type. A `run-instances --dry-run` succeeds regardless and had made me think the plan was upgraded; it was not. Nothing ever ran, and both partial stacks were destroyed.

Since the stack had never run, I reviewed it before spending anything. The review found problems that would each have broken the run after the plan upgrade:

- The compose file passed `-ports=8080-8095` next to the default `-port=8080`. nbio bound 8080 twice; the second bind failed and the server stayed up listening on nothing, logging `Accept failed` thousands of times a second. I reproduced it in Docker. The server now drops repeated ports and exits if a port is not accepting after start.
- Cloud-init cloned `main`, which does not contain the AWS stack, the load generator or `-ports`. `git_ref` is now required and the built SHA is written to `~/GIT_SHA`.
- Tags on `aws_spot_instance_request` do not reach the launched instance (the provider documents this), so peer discovery by tag would have found nothing. The stack now uses `aws_instance` with `instance_market_options`.
- Amazon Linux 2023 has no docker compose plugin. Cloud-init now installs it.
- With Docker's bridge and published ports, every connection would also take a NAT conntrack entry, and 1M would reach `nf_conntrack_max`. Server and loadgen use host networking.
- The default fleet (4 + 4 x 2 = 12 vCPU) exceeded the quota of 8. Defaults were then set to 1 `r6a.large` + 3 `m6a.large`, and later changed to free-plan types (see the correction below).
- `go test` ran no tests. `main_test.go` now covers port parsing, the duplicate-port case, the listening check, the cgroup reader, and echo on two ports plus the 503 guard, run with `-race`.

Because the credit is limited ($200, target under $30), cost guards were added: an on-instance shutdown timer, a watchdog Lambda that terminates any `Project=millionws-bench` instance past its deadline (checked every 10 minutes, IAM limited to that tag), and `scripts/kill-bench.sh`. The runbook with the staged plan and per-stage costs is [aws-runbook.md](aws-runbook.md). The whole setup is estimated at about $3.50 on-demand for every stage including a second 1M attempt, versus the $296 per month the full on-demand fleet would cost if forgotten.

What this taught: a dry run does not exercise account-level restrictions, and a stack that only passes `validate` can still be broken in every deployment detail. Local Docker reproductions of the cloud-init logic found bugs that no static check did.

Correction, later the same day: I first concluded the free plan itself blocked the launch and asked for an upgrade. That was wrong. The free plan only accepts certain instance types (`aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true` lists them, and the error message says so). Real launch probes of `m7i-flex.large` (on-demand and Spot) and `c7i-flex.large` succeeded and were terminated within seconds. The defaults are now those types: 1 `m7i-flex.large` server (8 GiB, container limited to 6 GiB with the new `server_mem_limit`) and 3 `c7i-flex.large` clients (4 GiB), still 8 vCPU. The estimate for every stage twice on-demand is about $3.28.

## September 2026, 30th: canary on EC2 stops at 76,952 connections

First run on real instances ([results/aws/2026-09-30-canary](../results/aws/2026-09-30-canary/README.md)): 1 `m7i-flex.large` server and 1 `c7i-flex.large` client, target 100,000.

- The stack applied cleanly, discovery and the git checkout worked, and the ramp started. But the server container had not started at all: compose asked for `nofile` 2,097,152 and cloud-init set `fs.nr_open` to 2,000,000, so runc refused. The Hetzner stack had the same mismatch. Both compose files now use 2,000,000.
- The server then held 76,952 connections and no more. Memory (417 MiB of 6 GiB), CPU (3 to 5%) and every bandwidth and packet-rate allowance were fine. SSH, Prometheus and Grafana on the same instance started timing out intermittently. ENA counters showed `conntrack_allowance_available: 0` and `conntrack_allowance_exceeded` around 18,000.
- Cause: the security group tracks each connection and an instance can track only so many. The limit was about 77,000 here. Connections are untracked only when the security group allows `0.0.0.0/0` in both directions, which the stack did not (a self-referencing rule and single-IP rules are tracked). So the risk written down in the roadmap earlier the same day ("watch `conntrack_allowance_exceeded`") turned out to be the binding limit, and it binds at 8% of the target.
- Two of my own diagnostic mistakes cost time: the first `ethtool` calls printed nothing because `ethtool` is not installed on Amazon Linux 2023 and my ssh wrapper discarded stderr, and I briefly wrote the interface name as `ens5`. I only had the real counters once I installed `ethtool` and looked the interface up. Before that the conntrack cause was a hypothesis, not a finding.

Memory per connection on EC2 was about 5.3 to 5.5 KiB all-in, close to the local 4.91 KiB. Stack destroyed afterwards, cost about $0.15.

