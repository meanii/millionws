# AWS runbook

How to run the EC2 load test, what it costs, and how it is kept from running up a bill. The stack is `infra/opentofu/aws-ec2`. The plan and the reasoning behind it are in [roadmap.md](roadmap.md).

Status on 2026-09-30: the first two apply attempts were refused by `RunInstances` because they asked for instance types the free plan does not allow (see [Troubleshooting](#troubleshooting)). The defaults were then changed to free-plan types, and single-instance launch probes of `m7i-flex.large` (on-demand and Spot) and `c7i-flex.large` succeeded. The stack itself is validated (`tofu validate`, `tofu plan`, unit and end-to-end tests, local Docker runs).

## Before the first apply

1. **Instance types.** On the AWS free plan `RunInstances` only accepts a short list of types (`t3/t4g/t8i` micro and small, `c7i-flex.large`, `m7i-flex.large`; list them with `aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true`). Any other type fails with `InvalidParameterCombination: The specified instance type is not eligible for Free Tier`. The defaults are now free-plan eligible, so **no plan upgrade is needed**. Upgrading to the paid plan (Billing console, credit stays) would allow larger types such as `r6a.large` for more memory headroom.
2. **vCPU quota.** The account has 8 for Spot standard and 8 for on-demand standard instances. The default fleet is exactly 8 vCPU (1 server + 3 clients, 2 vCPU each; all the free-plan `*-flex.large` types have 2 vCPU). Any bigger fleet needs a quota increase first.
3. **An EC2 key pair** in the region (`millionws-bench` exists in `us-east-1`; the private key is `~/.ssh/millionws-bench.pem`).
4. **Push the commit you want to test.** Cloud-init clones `repo_url` and checks out `git_ref`. The default branch `main` has neither the AWS stack nor the load generator, so `git_ref` is a required variable with no default.
5. **Your public IP** for `my_ip`: `curl -s https://checkip.amazonaws.com`.

## Stages

Run them in order and run `tofu destroy` after each. Every stage after the canary is only worth running if the previous one was clean.

Common flags: `-var my_ip=<ip>/32 -var key_name=millionws-bench -var git_ref=<sha>`. Add `-var use_spot=false` for on-demand.

| Stage | Extra flags | Fleet | Time |
| --- | --- | --- | --- |
| Canary, 100k | `-var client_count=1 -var conns_per_client=100000 -var max_runtime_minutes=120` | 1 server + 1 client | 2 h |
| 500k | `-var client_count=2 -var conns_per_client=250000 -var max_runtime_minutes=120` | 1 server + 2 clients | 2 h |
| 1M | defaults (3 clients x 334,000) | 1 server + 3 clients | 3 h |

```sh
cd infra/opentofu/aws-ec2
tofu init
tofu apply -var my_ip=... -var key_name=millionws-bench -var git_ref=<sha> \
  -var client_count=1 -var conns_per_client=100000 -var max_runtime_minutes=120
# ... run and record (below) ...
tofu destroy -var my_ip=... -var key_name=millionws-bench -var git_ref=<sha>
```

`conns_per_client` is split across `client_replicas` (default 4) loadgen containers and rounded down, so pick a multiple of 4. Each replica dials 1,000 connections per second by default, so 1M is reached in a few minutes; the local benchmark showed 5,000 dials per second is safe.

## What the stack builds

- One VPC, one public subnet, one availability zone. Traffic between instances uses private IPs, so there is no NAT gateway, no load balancer and no data transfer charge.
- One server (`m7i-flex.large`, 2 vCPU, 8 GiB) listening on 16 ports (8080-8095), and N clients (`c7i-flex.large`, 2 vCPU, 4 GiB) each running 4 loadgen containers that spread over all 16 ports. One client IP holds about 64,000 connections per server port, so 3 clients allow about 3,000,000.
- The server container is limited to `server_mem_limit` (default `6g` of the 8 GiB, leaving room for the OS, Prometheus and Grafana on the same machine). The server sizes its Go memory limit and the 90% admission guard from that cgroup limit. 1M connections need about 4.7 GiB at the measured 4.91 KiB each, so 1M fits with about 1.3 GiB to spare, the tightest case in the plan; if it does not fit, the 503 guard turns clients away instead of the process being killed, and that count is the result. A 4 GiB client holds about 334,000 connections (about 2.2 GiB at 6.6 KiB each).
- Server and loadgens use Docker host networking, so connections do not each take a Docker NAT conntrack entry (1M would hit `nf_conntrack_max` of 1,048,576).
- Prometheus and Grafana run on the server. Grafana is on port 3000 and Prometheus on 9090, reachable only from `my_ip`. Grafana has anonymous admin access enabled, so the security group is the only protection: keep `my_ip` at a /32.
- Server and clients find each other through the EC2 API (instances tagged `Name=millionws-server` and `millionws-client-N`), so there are no Terraform cross-references. Each waits up to 20 minutes for the other.
- Cloud-init writes the commit it built to `/home/ec2-user/GIT_SHA` and logs to `/tmp/cloud-init.log`.

## Recording a run

The roadmap requires each run to record instance types, region, kernel version, Go version, commit SHA and the exact command. Results go in `results/aws/<date>-<connections>/` with Grafana screenshots and the raw numbers.

- Commit: `cat ~/GIT_SHA` on any instance.
- Kernel: `uname -r`. Go version: from the Dockerfile's `golang:1.25-alpine` image.
- Server progress: Grafana `http://<server_public_ip>:3000`, or `curl localhost:8080/metrics | grep millionws_` on the server. Loadgen progress: `docker logs loadgen-1` on a client (a line every 10 seconds).
- Memory per connection: (server RSS at N connections minus RSS with none) divided by N, with kernel socket memory reported separately, as in the local benchmark.
- Watch `conntrack_allowance_exceeded` on each instance: `ethtool -S eth0 | grep conntrack`. The security group's self-referencing rule is tracked, and AWS drops packets once an instance reaches its per-type tracked-connection limit. The limit for these instance types was not found in the AWS documentation, so this needs checking on the first run.

## Cost

Prices are us-east-1 as of 2026-09-30. On-demand comes from the AWS pricing API, Spot from `describe-spot-price-history` (it moves). Each instance also costs about $0.0087 per hour for its 30 GB gp3 volume and public IPv4 address.

| Instance | On-demand per hour | Spot per hour |
| --- | --- | --- |
| `m7i-flex.large` (server) | $0.0958 | about $0.037 to 0.042 |
| `c7i-flex.large` (client) | $0.0848 | about $0.026 to 0.035 |

Estimated cost of the staged plan (estimates, not measured bills; Spot uses the midpoint of the price ranges above):

| Stage | On-demand | Spot |
| --- | --- | --- |
| Canary, 100k, 2 h | $0.40 | about $0.17 |
| 500k, 2 h | $0.58 | about $0.25 |
| 1M, 3 h | $1.15 | about $0.49 |
| 1M second attempt, 3 h | $1.15 | about $0.49 |
| Total | about $3.28 | about $1.40 |

Target budget: stay under $30 of the $200 credit. Even every stage twice on-demand stays far below that. The risk is a forgotten stack: the full on-demand fleet costs about $9.24 per day and about $281 per month.

## Cost guards

Three independent layers, so one failing does not leave the fleet running:

1. **On-instance timer.** Cloud-init runs `shutdown -h +max_runtime_minutes` (default 240), and instances use `instance_initiated_shutdown_behavior = "terminate"`, so a shutdown deletes the instance.
2. **Watchdog Lambda** (`watchdog.tf`, `guard/guard.py`). EventBridge runs it every 10 minutes. It terminates any instance tagged `Project=millionws-bench` that has run longer than `max_runtime_minutes + guard_grace_minutes` (default 240 + 15). It runs outside the instances, so it still works if cloud-init failed or the timer was removed, and it stays deployed after the instances are gone. Its IAM policy can terminate only instances with that tag. The provider's `default_tags` put the tag on every resource.
3. **Manual kill switch.** `scripts/kill-bench.sh [region]` terminates every tagged instance immediately.

The guards terminate instances only. Root volumes are deleted with their instance; the VPC, subnet, internet gateway, security group and IAM roles cost nothing, but run `tofu destroy` when done, which also removes the Lambda.

Spot requests are `one-time`, so an interruption ends the instance instead of relaunching a replacement that keeps billing.

Also worth doing in the console: a budget alert at $25 (a $100 monthly budget already exists).

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `InvalidParameterCombination: ... not eligible for Free Tier` | The account is on the free plan and the instance type is not on its list. Use a free-plan type (Before the first apply, step 1) or upgrade the plan. A `run-instances --dry-run` succeeds regardless, so it proves nothing; probe with a real launch and terminate it at once. |
| `VcpuLimitExceeded` | The fleet needs more vCPU than the quota. Reduce `client_count` or request a higher quota. |
| Server container is up but every port is closed, log full of `Accept failed` | The same port listed twice (for example `-port=8080` default plus `-ports=8080-8095`). Fixed in the server: repeats are dropped and the server exits if a port is not accepting after start. |
| Server waits 20 minutes and Prometheus has no client targets | Instances were not found by tag. Spot instances launched through `aws_spot_instance_request` do not get the request's tags; the stack uses `aws_instance` with `instance_market_options` for that reason. |
| Cloud-init fails at `cd .../deploy/aws` | `git_ref` points at a commit without the AWS stack, or was not pushed. |
| `docker compose` not found | Amazon Linux 2023 does not package the compose plugin; cloud-init installs v2.29.7. |
| `tofu apply` says `No valid credential sources found` | Credentials are not in the shell. With `aws login`, run `eval "$(aws configure export-credentials --format env)"` in the same shell. |

## Not yet verified on real instances

- Lambda, EventBridge and IAM creation on the free plan (the launch probes covered EC2 only).
- The whole cloud-init path (compose plugin download, image builds, discovery).
- The watchdog terminating a real instance (unit-tested against a stub only).
- ENA connection-tracking limits under 1M connections.
- A loadgen race: a connection that closes before it is registered stays counted as active.
