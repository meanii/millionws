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

Cost check: Hetzner raised cloud prices in June 2026. The comment in `infra/terraform/hetzner/main.tf` had `ccx33` at €0.077 per hour; the listed price is now €0.2227 per hour. A full 1M run with enough client machines came to an estimated €6 per hour.

Decision: I have $200 of AWS promotional credit, so the load tests move to plain EC2 in one availability zone: one server and four clients, talking over private IPs so data transfer is free. The server listens on 16 ports, which gives each client IP 16 × 64,000 possible connections. The EKS setup stays in the repository as the earlier approach.
