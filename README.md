# MillionWS

MillionWS is a WebSocket echo server in Go, written to find out what it takes to hold 1,000,000 concurrent connections on one machine, and what each connection costs in memory, CPU, and file descriptors.

The server does as little as possible on purpose: it accepts connections, echoes messages, and exports metrics. There is no authentication, no persistence, and no application protocol. The interesting part is the measurement, the tuning, and the notes on what broke along the way.

## Status

Work in progress. The target of 1,000,000 connections has not been reached yet.

| Stage | State |
| --- | --- |
| Echo server with Prometheus metrics | Done |
| Switch from gorilla/websocket to nbio (epoll) | Done, measured |
| Grafana dashboard, auto-provisioned | Done |
| Single-server deployment on Hetzner Cloud | Done |
| Go load generator (`cmd/loadgen`) | Done |
| Local benchmark with the server capped at 1 CPU and 1 GiB | Done |
| EC2 stack (OpenTofu), cost guards, tests | Done; first canary ran on 2026-09-30 ([runbook](docs/aws-runbook.md)) |
| AWS EC2 runs | Done for 1M: 999,999 connections on one `m7i-flex.large` ([results](results/aws/2026-09-30-1m/README.md)); the 500k stage was skipped |

The plan, the open items, and the cost estimates are in [docs/roadmap.md](docs/roadmap.md). How to run and pay for the AWS test, and how it is kept from overspending: [docs/aws-runbook.md](docs/aws-runbook.md). A dated log of decisions and mistakes is in [docs/journey.md](docs/journey.md).

## Results so far

Local benchmark on 2026-09-28: the server in a Docker container limited to 1 CPU and 1 GiB with no swap, clients opening 1,000 connections per second until the server stops accepting, one 32-byte message per connection every 30 seconds. Medians of three runs per version:

| Server version | Peak connections | Memory per connection | Kernel part | Go part | After the peak |
| --- | --- | --- | --- | --- | --- |
| gorilla/websocket, goroutine per connection | 39,770 | 25.11 KiB | 4.00 KiB | 21.08 KiB | OOM-killed |
| nbio, first version | 193,532 | 5.31 KiB | 3.96 KiB | 1.35 KiB | OOM-killed |
| nbio, current | 190,894 | 4.91 KiB | 3.83 KiB | 1.08 KiB | still running, new clients get 503 |

The current version holds slightly fewer connections than the first nbio version but does not crash at its limit. Most of each connection's cost is now kernel memory for the TCP socket, which the Go code cannot reduce. Near the memory limit the GC uses the whole CPU core and echo p99 is about 93 ms.

EC2, 2026-09-30, one `m7i-flex.large` server (8 GiB, 2 vCPU, container limited to 6 GiB), on-demand, connections idle with one 32-byte message every 30 s:

| Run | Connections held | Memory per connection (all-in) | Notes |
| --- | --- | --- | --- |
| Canary, 1 client | 76,952 | about 5.4 KiB | stopped by security-group connection tracking, not by the server |
| 1 client | 250,000 | 5.0 KiB | connection tracking removed (open security group, filtering in a network ACL) |
| 3 clients | 999,999 | 5.27 KiB | the server's `MaxLoad` of 1,000,000; 5.03 of 6 GiB; echo p50 5.7 ms, p99 406 ms; no rejections |

The 1M run was one five-minute hold at about 84% of the container's memory limit, and the number is the server's configured cap, not the machine's. Details, caveats and cost (about $0.07 for the 1M fleet): [results/aws](results/aws). A repeat of the 1M run (999,996 held for 18 minutes) has the evidence: Grafana screenshots, exported Prometheus history and host snapshots in [results/aws/evidence](results/aws/evidence/README.md).

Mumbai (ap-south-1), same server type, all times IST, 999,996 connections: held 34 minutes at a stretch, 5.3 KiB per connection all-in (5,155 to 5,224 of 6,144 MiB), echo p50 3.5 ms and p99 399 ms. The server was OOM-killed three times, each within 14 seconds of a 30-second CPU profile I ran on it (the third on purpose): a stalled read path fills socket buffers at about 120 MiB per second and a 6 GiB container has room for about 7 to 12 seconds. Video, terminal recording, Grafana screenshots, raw Prometheus data and kernel logs: [results/aws/2026-09-30-mumbai-1m](results/aws/2026-09-30-mumbai-1m/README.md).

Every step between these rows, the method, and its limits: [docs/local-benchmark.md](docs/local-benchmark.md), [docs/journey.md](docs/journey.md), and the raw data in [results/local](results/local).

## How it works

| Part | Technology |
| --- | --- |
| Language | Go 1.25 |
| WebSocket | [nbio](https://github.com/lesismal/nbio) v1.6.8, event loop on epoll |
| Metrics | Prometheus client, scraped every 5 s |
| Dashboards | Grafana, provisioned from `deploy/grafana/provisioning` |
| Load testing | `cmd/loadgen` (Go, nbio) for connection counts; Locust for the earlier EKS setup |
| Infrastructure | Terraform for Hetzner Cloud and AWS EKS |

With gorilla/websocket each connection needs a goroutine blocked on read, so 1M connections means 1M goroutines and their stacks. nbio registers every socket with epoll and runs callbacks from a small pool of goroutines, so the goroutine count stays flat as connections grow.

When the server runs under a cgroup v2 memory limit, it manages memory itself (`memory.go`):

- Once a second it sets the Go soft memory limit to 88% of the cgroup limit minus the memory the kernel holds for sockets. The kernel's share grows with every connection, so a fixed `GOMEMLIMIT` would be wrong at most connection counts. Setting `GOMEMLIMIT` turns this off.
- Above 90% of the cgroup limit, `/ws` answers 503 until usage falls below 85%. This keeps the process out of the OOM killer, which would close every connection at once.

The listener uses `tcp4` when `-addr` is an IPv4 address. A dual-stack `[::]` listener turns every IPv4 client into an IPv6 socket, which uses more kernel memory.

### Endpoints

| Path | Description |
| --- | --- |
| `/ws` | WebSocket endpoint; echoes every message back |
| `/health` | Returns `200 OK` |
| `/metrics` | Prometheus metrics |

The server listens on `0.0.0.0:8080` by default. Use `-addr` and `-port` to change it, and `-pprof` to serve `/debug/pprof/` on the same port (a 30 second CPU profile at 1M connections stalls the server long enough to get it OOM-killed; see [docs/aws-runbook.md](docs/aws-runbook.md)). `-maxload` sets the maximum number of open connections (default 1,000,000): nbio refuses more, **including `/metrics` and `/health` requests**, which use the same ports, so keep it above the number of connections you plan to hold.

### Metrics

| Metric | Type |
| --- | --- |
| `millionws_connections_total` | Counter of accepted connections |
| `millionws_connections_active` | Gauge of open connections |
| `millionws_disconnections_total` | Counter of closed connections |
| `millionws_upgrade_errors_total` | Counter of failed WebSocket handshakes |
| `millionws_connections_rejected_total` | Counter of 503 answers from the memory guard |
| `millionws_go_memory_limit_bytes` | Gauge of the Go memory limit the server set |

Process memory, goroutine count, and open file descriptors come from the default Go and process collectors.

## Quickstart

Local, with [just](https://github.com/casey/just) and Docker:

```sh
just run                # build and start the server on :8080
just start-monitoring   # Prometheus on :9090, Grafana on :8001
```

Local benchmark, the server capped at 1 CPU and 1 GiB (needs Docker and Python 3; see [docs/local-benchmark.md](docs/local-benchmark.md)):

```sh
just bench nbio-tuned   # one run of one version, results in results/local/
just bench-matrix 3     # every version 3 times, plus a comparison table
```

On Hetzner Cloud (creates one server; you are billed per hour until you destroy it):

```sh
cd infra/opentofu/hetzner
export HZ_TOKEN=...     # Hetzner Cloud API token
make start              # tofu apply; cloud-init installs Docker and starts the stack
make stop               # tofu destroy
```

On AWS EC2 (one server and N clients on Spot or on-demand; default instance types work on the AWS free plan, see [docs/aws-runbook.md](docs/aws-runbook.md)):

```sh
cd infra/opentofu/aws-ec2
tofu apply -var my_ip=<ip>/32 -var key_name=<key pair> -var git_ref=<pushed branch or SHA>
tofu destroy ...        # same variables; every session ends here
scripts/kill-bench.sh   # emergency: terminate every tagged instance now
```

Instances terminate themselves after 4 hours and a watchdog Lambda terminates any that outlive that, so a forgotten stack cannot bill for long.

The Hetzner stack exposes Grafana with the default `admin/admin` login on a public IP. Change the password or restrict the firewall before leaving it running.

## Repository layout

| Path | Contents |
| --- | --- |
| `main.go`, `memory.go` | The server |
| `cmd/loadgen` | Load generator: holds N connections and measures echo latency |
| `bench/local` | Local benchmark: Compose file, run and recording scripts, one file per server version |
| `results/local` | Benchmark output, one directory per run |
| `deploy/local` | Docker Compose for local Prometheus and Grafana |
| `deploy/hetzner` | Docker Compose for the single-server Hetzner stack |
| `deploy/aws` | Docker Compose for the server side of the EC2 stack |
| `deploy/grafana` | Grafana datasource and dashboard provisioning |
| `deploy/millionws` | Kubernetes manifests (EKS approach) |
| `infra/opentofu/hetzner` | OpenTofu for one Hetzner Cloud server |
| `infra/opentofu/aws-ec2` | OpenTofu for the EC2 load-test stack (server + clients) and the cost watchdog Lambda (`watchdog.tf`, `guard/`) |
| `scripts` | `kill-bench.sh`, the emergency terminate |
| `infra/opentofu/clusters`, `modules` | OpenTofu for two EKS clusters (earlier approach, see journey) |
| `locust` | Locust test and Locust Operator manifests |
| `docs` | Roadmap, journey, benchmark method, and the AWS runbook |

## References

- https://www.freecodecamp.org/news/million-websockets-and-go-cc58418460bb/
- https://dyte.io/blog/scaling-websockets-to-millions/
- https://github.com/gobwas/ws-examples/blob/master/src/chat/main.go#L135
- https://blog.ukena.de/posts/2021/11/provisioning-grafana-dashboards-in-docker/

## License

MIT, see [LICENSE](LICENSE).
