# AWS canary, 2026-09-30: stopped at 76,952 connections by security-group connection tracking

The first run on real EC2 instances. Target 100,000 connections; the server held at most 76,952. Not a successful 100k run, and the reason is a limit of the setup, not of the server.

## Setup

| | |
| --- | --- |
| Region / AZ | us-east-1, one AZ, private IPs between instances |
| Commit | `110c2b6c952d416a581ef7a179183a5504f1fc19` (branch `feat/million-connections`) |
| Server | `m7i-flex.large` (2 vCPU, 8 GiB), on-demand, container limit 6 GiB, `-ports=8080-8095 -keepalive=0s`, host networking |
| Client | 1 x `c7i-flex.large` (2 vCPU, 4 GiB), on-demand, 4 loadgen replicas x 25,000, host networking |
| Kernel / OS | 6.12.110-135.201.amzn2023.x86_64, Amazon Linux 2023 |
| Go | 1.25 (`golang:1.25-alpine` build image) |
| Command | `tofu apply -var my_ip=<ip>/32 -var key_name=millionws-bench -var git_ref=110c2b6... -var use_spot=false -var client_count=1 -var conns_per_client=100000 -var max_runtime_minutes=120` |
| Duration | about 37 minutes, 02:20 to about 02:57 UTC; estimated cost about $0.15 |

## What was measured

| Measurement | Value |
| --- | --- |
| Peak connections held | 76,952 (76,943 at 02:33, 76,952 at 02:50) |
| Upgrade errors, 503 rejections | 0, 0 |
| Server process RSS | 118 MB at 74,711 connections, 141 MB at the end |
| Server container memory (cgroup, all-in) | 386.3 MiB at 74,711 connections, 416.5 MiB at the end: about 5.3 to 5.5 KiB per connection including the process baseline. Local benchmark: 4.91 KiB. |
| Server CPU | 3 to 5% of the 2 vCPU during the hold |
| ENA `conntrack_allowance_exceeded` | 17,907 at 02:50, 17,927 at 02:54 (packets dropped) |
| ENA `conntrack_allowance_available` | 0 |
| Other ENA allowances (bandwidth in/out, pps) | 0 exceeded |
| Client dial errors | 2,400 `timeout` per replica |

Memory and CPU are nowhere near their limits: the 6 GiB container used 7% of its limit.

## Finding

The security group tracks every connection, and each instance has a maximum number of tracked connections. The server reached that maximum at about 77,000 connections. After that, packets for new connections are dropped: dials time out, and new SSH, Prometheus and Grafana connections to the same instance failed intermittently while the established connections carried on. Evidence: `conntrack_allowance_available` was 0 and `conntrack_allowance_exceeded` counted about 18,000 drops, while CPU, memory, bandwidth and packet-rate allowances were all fine.

Connections are untracked only when the security group has rules using `0.0.0.0/0` (or `::/0`) in both directions ([AWS documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-connection-tracking.html#untracked-connections)). The stack allowed instance-to-instance traffic with a self-referencing group rule and SSH, Grafana and Prometheus from one IP, so every flow was tracked. As built, this stack cannot exceed the per-instance tracked-connection limit, about 77,000 on these instance types, so 1,000,000 connections were not reachable on it regardless of the server.

The AWS documentation says the limit varies by instance type but gives no numbers. On `m7i-flex.large` it is about 77,000.

## Bugs found by the run

- The server container did not start: compose asked for `nofile` 2,097,152 while cloud-init set `fs.nr_open` to 2,000,000, so runc refused (`error setting rlimit type 7: operation not permitted`). The clients dialed a closed port until the server was restarted by hand after raising `nr_open`. Fixed: compose now asks for 2,000,000 (both the AWS and Hetzner files had the mismatch).
- `ethtool` is not installed on Amazon Linux 2023, and the interface is not `ens5`; use `ethtool -S $(ip -o -4 route show to default | awk '{print $5}')` after `dnf install -y ethtool`.

## Checked and working

- Spot and on-demand launch of `m7i-flex.large` and `c7i-flex.large` on the AWS free plan; the whole 17-resource stack, including the Lambda, EventBridge rule and IAM roles, applied and destroyed cleanly.
- Peer discovery through the EC2 API by tag, the git ref checkout (`~/GIT_SHA` matched the commit), the compose plugin install, host networking, and 16 ports with no duplicate.
- The client rebooting and reconnecting: about 75,000 connections came back in about 2 minutes.
- Not exercised: the watchdog Lambda terminating an instance, and the on-instance shutdown timer (the stack was destroyed first).
