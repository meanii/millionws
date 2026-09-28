# MillionWS

MillionWS is a WebSocket echo server in Go, written to find out what it takes to hold 1,000,000 concurrent connections on one machine, and what each connection costs in memory, CPU, and file descriptors.

The server does as little as possible on purpose: it accepts connections, echoes messages, and exports metrics. There is no authentication, no persistence, and no application protocol. The interesting part is the measurement, the tuning, and the notes on what broke along the way.

## Status

Work in progress. The target of 1,000,000 connections has not been reached yet.

| Stage | State |
| --- | --- |
| Echo server with Prometheus metrics | Done |
| Switch from gorilla/websocket to nbio (epoll) | Done, not yet re-measured |
| Grafana dashboard, auto-provisioned | Done |
| Single-server deployment on Hetzner Cloud | Done |
| Go load generator that can open 250k connections per machine | Not started |
| Local run at 300k to 500k connections | Not started |
| AWS EC2 runs from 100k up to 1M connections | Not started |

The plan, the open items, and the cost estimates are in [docs/roadmap.md](docs/roadmap.md). A dated log of decisions and mistakes is in [docs/journey.md](docs/journey.md).

## Measurements so far

One measurement exists. It was taken with the first version of the server, which used gorilla/websocket and one goroutine per connection.

| Metric | Value |
| --- | --- |
| Active connections | 5,000 |
| Process memory | 192 MiB |
| Goroutines | 5,010 |
| Open file descriptors | 5,010 |

That is about 38 KB per connection. The goroutine count matching the connection count is the cost the nbio switch is meant to remove. The nbio version has not been measured yet, so no figure is claimed for it.

## How it works

| Part | Technology |
| --- | --- |
| Language | Go 1.25 |
| WebSocket | [nbio](https://github.com/lesismal/nbio) v1.6.8, event loop on epoll |
| Metrics | Prometheus client, scraped every 5 s |
| Dashboards | Grafana, provisioned from `deploy/grafana/provisioning` |
| Load testing | Locust (current); a Go client is planned |
| Infrastructure | Terraform for Hetzner Cloud and AWS EKS |

With gorilla/websocket each connection needs a goroutine blocked on read, so 1M connections means 1M goroutines and their stacks. nbio registers every socket with epoll and runs callbacks from a small pool of goroutines, so the goroutine count stays flat as connections grow.

### Endpoints

| Path | Description |
| --- | --- |
| `/ws` | WebSocket endpoint; echoes every message back |
| `/health` | Returns `200 OK` |
| `/metrics` | Prometheus metrics |

The server listens on `0.0.0.0:8080` by default. Use `-addr` and `-port` to change it.

### Metrics

| Metric | Type |
| --- | --- |
| `millionws_connections_total` | Counter of accepted connections |
| `millionws_connections_active` | Gauge of open connections |
| `millionws_disconnections_total` | Counter of closed connections |

Process memory, goroutine count, and open file descriptors come from the default Go and process collectors.

## Quickstart

Local, with [just](https://github.com/casey/just) and Docker:

```sh
just run                # build and start the server on :8080
just start-monitoring   # Prometheus on :9090, Grafana on :8001
```

On Hetzner Cloud (creates one server; you are billed per hour until you destroy it):

```sh
cd infra/terraform/hetzner
export HZ_TOKEN=...     # Hetzner Cloud API token
make start              # terraform apply; cloud-init installs Docker and starts the stack
make stop               # terraform destroy
```

The Hetzner stack exposes Grafana with the default `admin/admin` login on a public IP. Change the password or restrict the firewall before leaving it running.

## Repository layout

| Path | Contents |
| --- | --- |
| `main.go` | The server |
| `deploy/local` | Docker Compose for local Prometheus and Grafana |
| `deploy/hetzner` | Docker Compose for the single-server Hetzner stack |
| `deploy/grafana` | Grafana datasource and dashboard provisioning |
| `deploy/millionws` | Kubernetes manifests (EKS approach) |
| `infra/terraform/hetzner` | Terraform for one Hetzner Cloud server |
| `infra/terraform/clusters`, `modules` | Terraform for two EKS clusters (earlier approach, see journey) |
| `locust` | Locust test and Locust Operator manifests |
| `docs` | Roadmap and journey |

## References

- https://www.freecodecamp.org/news/million-websockets-and-go-cc58418460bb/
- https://dyte.io/blog/scaling-websockets-to-millions/
- https://github.com/gobwas/ws-examples/blob/master/src/chat/main.go#L135
- https://blog.ukena.de/posts/2021/11/provisioning-grafana-dashboards-in-docker/

## License

MIT, see [LICENSE](LICENSE).
