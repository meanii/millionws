# AWS run, 2026-09-30: 250,000 connections on one client, past the connection-tracking limit

Second run on real EC2 instances, after the security group was opened and filtering moved to a subnet network ACL (see [the first canary](../2026-09-30-canary/README.md), which stopped at 76,952). One client, first 100,000 connections, then a fifth loadgen container added by hand to reach 250,000.

## Setup

| | |
| --- | --- |
| Region / AZ | us-east-1, one AZ, private IPs between instances |
| Commit | `07cf492b35edf06570d2994a6e50c69868b6d2ba` (recorded in `~/GIT_SHA`); the network ACL and security group changes are OpenTofu only (`75c0cfe`) |
| Server | `m7i-flex.large` (2 vCPU, 8 GiB), on-demand, container limit 6 GiB, `-ports=8080-8095 -keepalive=0s`, host networking |
| Client | 1 x `c7i-flex.large` (2 vCPU, 4 GiB), on-demand, 4 loadgen replicas x 25,000 from cloud-init, plus one container of 150,000 started by hand (metrics on loopback) |
| Kernel | 6.12.110-135.201.amzn2023.x86_64, Amazon Linux 2023 |
| Command | `tofu apply -var my_ip=<ip>/32 -var key_name=millionws-bench -var git_ref=07cf492 -var use_spot=false -var client_count=1 -var conns_per_client=100000 -var max_runtime_minutes=120` |
| Network | security group open both ways so flows are untracked; subnet NACL allows SSH, Grafana and Prometheus from the operator only and denies the service ports |
| Duration | about 7 minutes, 03:12 to 03:19 UTC, then destroyed; estimated cost under $0.05 |

## Results

| Measurement | 100,000 | 250,000 |
| --- | --- | --- |
| Connections held on the server | 100,000 (03:14) | 250,000 (03:16:16) |
| Upgrade errors, 503 rejections | 0, 0 | 0, 0 |
| ENA `conntrack_allowance_exceeded` | 0 | 0 |
| ENA `conntrack_allowance_available` | 76,957 (unchanged) | 76,957 (unchanged) |
| bandwidth and packet-rate allowances exceeded | 0 | 0 (read at 03:16, right after the ramp) |
| Server container memory (cgroup, all-in) | 676 MiB at 129,058 connections: 5.4 KiB per connection with the process baseline | 1.193 GiB: 5.0 KiB per connection |
| Server process RSS | 200 MB at 129,058 | 308 MB |
| Server CPU (`docker stats`, percent of one core; 2 vCPU host) | 13% at 129,058 | 10 to 12% |
| Open file descriptors | 129,084 | 250,026 |
| Goroutines | 29 | 30 |
| Echo latency, p50 / p99 (measured by the loadgen, 1 minute window) | not recorded | 1.1 ms / 236 ms |
| Client memory (loadgen containers) | 157 MiB per 25,000 (6.4 KiB per connection) | 816 MiB for the 150,000 container (5.6 KiB per connection) |

The all-in 5.0 KiB per connection on EC2 is close to the local benchmark (4.91 KiB, 2% lower); the two setups differ (bridge versus host networking, different kernel), and I did not investigate the difference. The server used 20% of its 6 GiB limit at 250,000 connections.

The ENA connection-tracking allowance stayed at its full 76,957 the whole time, so the flows were untracked: the fix works. In the first canary the same counter reached 0 at 76,952 connections.

## Verifying the network rules from outside

The security group is open to the world, so the network ACL is the only filter. Its behaviour was checked from a Lambda function (a non-operator AWS address), not only from the operator's IP:

- Blocked (connection timed out): 22 (SSH), 3000 (Grafana), 9090 (Prometheus), 8080, 8095 (server), 9101 (loadgen metrics), 443.
- Port 5555 answered "refused": the packet reached the host and nothing was listening. This is expected: replies to connections the instances open themselves need the port range 1024 to 65535 open inbound, so every service port has an explicit deny ahead of that rule. Anything new that listens on a port of 1024 or above needs its own deny rule.
- From the operator's IP: 22, 3000 and 9090 open; 8080, 8095 and 5555 not reachable.

One mistake while running: the extra loadgen container was first started with its metrics on port 9105, which the NACL does not deny, so it was reachable from the internet for about a minute (counters only). I restarted it bound to `127.0.0.1` and checked that 9105 was unreachable from outside.

## Not measured

- The p99 of 236 ms was measured at the loadgen on a 2 vCPU client running five processes, so it may be client-side queueing; I did not separate the two.
- Latency at 100,000.
