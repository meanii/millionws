# AWS runbook

How to run the EC2 load test, what it costs, and how it is kept from running up a bill. The stack is `infra/opentofu/aws-ec2`. The plan and the reasoning behind it are in [roadmap.md](roadmap.md).

Status on 2026-09-30 (three runs later the same day, the last holding 999,999 connections; see [results/aws](../results/aws)): the first two apply attempts were refused by `RunInstances` because they asked for instance types the free plan does not allow (see [Troubleshooting](#troubleshooting)). The defaults were then changed to free-plan types, and single-instance launch probes of `m7i-flex.large` (on-demand and Spot) and `c7i-flex.large` succeeded. The stack itself is validated (`tofu validate`, `tofu plan`, unit and end-to-end tests, local Docker runs).

## Before the first apply

1. **Instance types.** On the AWS free plan `RunInstances` only accepts a short list of types (`t3/t4g/t8i` micro and small, `c7i-flex.large`, `m7i-flex.large`; list them with `aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true`). Any other type fails with `InvalidParameterCombination: The specified instance type is not eligible for Free Tier`. The defaults are now free-plan eligible, so **no plan upgrade is needed**. Upgrading to the paid plan (Billing console, credit stays) would allow larger types such as `r6a.large` for more memory headroom.
2. **vCPU quota.** The account has 8 for Spot standard and 8 for on-demand standard instances. The default fleet is exactly 8 vCPU (1 server + 3 clients, 2 vCPU each; all the free-plan `*-flex.large` types have 2 vCPU). Any bigger fleet needs a quota increase first.
3. **An EC2 key pair** in the region (`millionws-bench` exists in `us-east-1`; the private key is `~/.ssh/millionws-bench.pem`).
4. **Push the commit you want to test.** Cloud-init clones `repo_url` and checks out `git_ref`. The default branch `main` has neither the AWS stack nor the load generator, so `git_ref` is a required variable with no default.
5. **Your public IP** for `my_ip`: `curl -s https://checkip.amazonaws.com`.

## Stages

Measured so far (2026-09-30, on-demand): 76,952 (first canary, stopped by connection tracking), 250,000 (one client) and 999,999 (three clients, the server's `MaxLoad`). The 500k stage was skipped. To repeat 1M, ask for 1,000,000 connections (`conns_per_client=333332` is 83,333 per replica, 999,996 in total), not 1,002,000, so the clients are not left dialing against the server's cap.

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

## Security-group connection tracking, and the network design that follows from it

A security group tracks every flow it permits, and an instance can track only a limited number: about 76,957 on `m7i-flex.large` (the ENA counter `conntrack_allowance_available` starts at that value). The first canary ([results/aws/2026-09-30-canary](../results/aws/2026-09-30-canary/README.md)) hit it at 76,952 connections and dropped packets. A flow is untracked only when the group has `0.0.0.0/0` rules in both directions ([AWS docs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-connection-tracking.html#untracked-connections)).

So the stack does this (`main.tf`):

- The **security group allows everything** in and out. That is what makes flows untracked.
- A **subnet network ACL does the filtering**: SSH (22), Grafana (3000) and Prometheus (9090) only from `my_ip`; the service ports (server 8080-8095, Grafana, Prometheus, loadgen metrics 9101 to 9100+`client_replicas`) denied to everyone else; inbound TCP 1024-65535 allowed so replies to the instances' own outbound connections (package repositories, git, the EC2 API) get in; ICMP "fragmentation needed" for path MTU discovery. Traffic between the two instances is inside the subnet, which a network ACL does not filter.
- The allowance stayed at its full 76,957 through the 250,000 and 1,000,000 runs, and the ACL was checked from a non-operator address (see [the 250k results](../results/aws/2026-09-30-250k/README.md#verifying-the-network-rules-from-outside)).

Consequences to keep in mind:

- **Any new listening port of 1024 or above is reachable from the internet** unless it has a deny rule (`local.denied_ports` in `main.tf`). Bind ad hoc processes to `127.0.0.1`. During the 250k run a loadgen metrics port outside the denied range was exposed for about a minute before I noticed.
- The open security group leaves the network ACL as the only filter. Read the plan output for `aws_network_acl.bench` before applying a change to it.
- Watch it on any instance: `sudo ethtool -S $(ip -o -4 route show to default | awk '{print $5}') | grep conntrack` (cloud-init installs `ethtool`).

## Another region and timezone (Mumbai, IST)

Everything is per region, so before `-var region=ap-south-1` (or any region other than us-east-1):

1. **Key pair.** Import the same public key: `aws ec2 import-key-pair --region <r> --key-name millionws-bench --public-key-material fileb://<(ssh-keygen -y -f ~/.ssh/millionws-bench.pem)`.
2. **vCPU quota.** Mumbai started with 5 on-demand standard vCPUs, so it could hold only two of the 2 vCPU instances. Request 8 (`aws service-quotas request-service-quota-increase --region <r> --service-code ec2 --quota-code L-1216C47A --desired-value 8`); it was approved in about three minutes.
3. **Instance types.** `m7i-flex.large` and `c7i-flex.large` were offered in all three Mumbai zones. Check with `describe-instance-type-offerings`.
4. **Timezone.** The `timezone` variable (default `Asia/Kolkata`) is set on every instance and passed to the containers, so logs, `date` and Grafana use it. Prometheus data itself is in UTC.

The Mumbai 1M run, with video, terminal recording, screenshots and raw data: [results/aws/2026-09-30-mumbai-1m](../results/aws/2026-09-30-mumbai-1m/README.md). Tooling for capturing that kind of evidence is in [scripts/evidence](../scripts/evidence): a per-host sampler that starts from boot, host snapshots, a Prometheus exporter, a Grafana video recorder (Playwright), a live terminal view for `asciinema`, and the plot script.

## Headroom at 1M: do not stall the server, and do not profile it

At 1M connections the server's container was at 5.2 of 6 GiB (84%). If the server stops reading its sockets for a few seconds, the kernel keeps accepting the clients' 33,000 messages per second into socket buffers, charged to the container at about 3.7 KiB each, so memory grows by about 120 MiB per second. The 920 MiB of headroom lasts about 7 seconds (about 12 with the Go heap shrinking). Past the limit the kernel OOM-kills the server, all 1M connections drop, and they take about 2 min 20 s to come back. The memory guard cannot prevent this: it only refuses new connections.

The tolerance can be estimated: socket buffers grew 130 to 132 MiB per second in five freeze tests (`scripts/evidence/stall.sh`, `SIGSTOP` for N seconds at about 1M connections), and the server survived exactly when (container limit minus memory in use) divided by 130 was longer than the freeze:

| Container limit | Freeze | Headroom | Predicted | Result |
| --- | --- | --- | --- | --- |
| 6,144 MiB | 5 s / 9 s | 1,028 MiB | 7.9 s | survived / killed |
| 6,500 MiB | 9 s / 14 s | 1,335 to 1,412 MiB | 10 to 11 s | survived / killed |
| 7,168 MiB | 14 s | 1,727 MiB | 13.3 s | killed |

So a 6 GiB container tolerates about 8 seconds and a 7 GiB one about 13, and each further GiB buys about 8 seconds; an 8 GiB machine cannot reach the 9 GiB a 30 second stall would need. A larger container is also partly used up by the Go heap (about 1.4 GiB at a 6 GiB limit, 1.7 GiB at 7 GiB). `-var server_mem_limit=7g` worked on the 8 GiB instance: it held 1.3M connections and, at 1.42M, the memory guard (90% of the container) refused further connections without a crash; the host, Prometheus and Grafana had about 0.8 GiB. The default is still 6g, which held 1,000,008 for 75 minutes. Results: [Mumbai validation](../results/aws/2026-09-30-mumbai-validation/README.md).

**Why, and what does not help** ([tcp buffer test](../results/aws/2026-09-30-tcp-buffer-test/README.md)): each socket that receives a message while the server is not reading is charged one 4 KiB page, the kernel charges it past the container's limit, and the OOM kill comes when the server next allocates. The growth stops at connections x 4 KiB (3.9 GiB at 1M) once every socket has one page. A per-socket cap (`tcp_rmem 4096 4096 4096`) and a global cap (`tcp_mem`, 128 MiB) both failed to stop it; the global cap also aborted about 21,000 connections. To survive a stall of any length, leave connections x 4 KiB of headroom: about 680k connections in a 6 GiB container, about 800k in 7 GiB (estimates).

In the first Mumbai run a **30 second CPU profile** (`/debug/pprof/profile?seconds=30`) killed the server three times; a 10 second one stalled it for about 10 seconds without a kill; heap and goroutine profiles were harmless. So `deploy/aws/compose.yml` no longer passes `-pprof`, and profiles at this scale should be heap only. If you need more margin: a container limit above 6 GiB (the host has 8 GiB, shared with Prometheus and Grafana) or a larger instance; I did not test either.

## The kernel's own connection tracking (a second, separate limit)

Even with the security group open, Linux's netfilter connection tracking (loaded by Docker) keeps a 256-byte entry per flow and drops **new** flows once `nf_conntrack_max` is full. The stack sets it to 1,048,576. A run that asked for 1.3M connections reached that at 1,048,576 tracked flows, and from then on the server dropped SSH, Prometheus scrapes and new client connections (`nf_conntrack: table full, dropping packet` in `dmesg` and in the instance's console output). The earlier 1M runs were only 4.6% below it (1,000,030 entries of 1,048,576 at the end of the 75 minute hold).

The server's cloud-init now exempts the service ports (the 1.42M run applied the same two rules by hand; a later small stack confirmed that cloud-init creates them at boot, `results/aws/2026-09-30-mumbai-validation/evidence/conntrack/cloud-init_notrack_check_1517IST.txt`): `iptables -t raw -I PREROUTING -p tcp --dport 8080:8095 -j CT --notrack` and the matching `OUTPUT --sport` rule. With 1,000,003 connections held, the table then had 47 entries. Clients are not exempted (they hold at most about 500k). Check it on a server with `cat /proc/sys/net/netfilter/nf_conntrack_count`. This is not the security group's tracking described above; it is a different limit with the same symptom (new flows time out while existing ones continue), so `conntrack_allowance_available` staying at its full value while SSH times out points here.

Findings are in [results/aws/2026-09-30-mumbai-validation](../results/aws/2026-09-30-mumbai-validation/README.md).

## What the stack builds

- One VPC, one public subnet, one availability zone. Traffic between instances uses private IPs, so there is no NAT gateway, no load balancer and no data transfer charge.
- One server (`m7i-flex.large`, 2 vCPU, 8 GiB) listening on 16 ports (8080-8095), and N clients (`c7i-flex.large`, 2 vCPU, 4 GiB) each running 4 loadgen containers that spread over all 16 ports. One client IP holds about 64,000 connections per server port, so 3 clients allow about 3,000,000.
- The server container is limited to `server_mem_limit` (default `6g` of the 8 GiB, leaving room for the OS, Prometheus and Grafana on the same machine). The server sizes its Go memory limit and the 90% admission guard from that cgroup limit. 1M connections need about 4.7 GiB at the measured 4.91 KiB each, so 1M fits with about 1.3 GiB to spare, the tightest case in the plan; if it does not fit, the 503 guard turns clients away instead of the process being killed, and that count is the result. A 4 GiB client holds about 334,000 connections (about 2.2 GiB at 6.6 KiB each).
- Server and loadgens use Docker host networking, so connections do not each take a Docker NAT conntrack entry (1M would hit `nf_conntrack_max` of 1,048,576).
- Prometheus and Grafana run on the server. Grafana is on port 3000 and Prometheus on 9090, reachable only from `my_ip`. Grafana has anonymous admin access enabled, so the network ACL is the only protection (the security group is open on purpose, see above): keep `my_ip` at a /32.
- Server and clients find each other through the EC2 API (instances tagged `Name=millionws-server` and `millionws-client-N`), so there are no Terraform cross-references. Each waits up to 20 minutes for the other.
- Cloud-init writes the commit it built to `/home/ec2-user/GIT_SHA` and logs to `/tmp/cloud-init.log`.

## Recording a run

The roadmap requires each run to record instance types, region, kernel version, Go version, commit SHA and the exact command. Results go in `results/aws/<date>-<connections>/` with Grafana screenshots and the raw numbers.

- Commit: `cat ~/GIT_SHA` on any instance.
- Kernel: `uname -r`. Go version: from the Dockerfile's `golang:1.25-alpine` image.
- Server progress: Grafana `http://<server_public_ip>:3000`, or `curl localhost:8080/metrics | grep millionws_` on the server. Loadgen progress: `docker logs loadgen-1` on a client (a line every 10 seconds).
- Memory per connection: (server RSS at N connections minus RSS with none) divided by N, with kernel socket memory reported separately, as in the local benchmark.
- Watch `conntrack_allowance_exceeded` and `conntrack_allowance_available` on each instance (see the connection-tracking section above; the interface is not called `ens5`, so use the command given there).

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

Both the on-instance timer and the watchdog Lambda have terminated real instances: the timer about 5 minutes after launch (AWS state reason `Client.InstanceInitiatedShutdown`), the Lambda at its first check after a 12 minute deadline (a `TerminateInstances` call by its role, 12 min 39 s after launch). See [results/aws/2026-09-30-cost-guard-test](../results/aws/2026-09-30-cost-guard-test/README.md).

**The watchdog terminates every `Project=millionws-bench` instance in its region that is older than its deadline.** Do not run a second stack in the same region with a shorter `max_runtime_minutes` than the first one needs, and do not test the guards in a region that has a run in progress.

**Two stacks at once.** IAM role and instance profile names are account-wide, so a second stack needs its own prefix (`-var iam_name_prefix=millionws-bench-b`), and each stack needs its own working directory and state (copy `infra/opentofu/aws-ec2`). Each region also has its own vCPU quota: a full fleet is 8 vCPU.

Also worth doing in the console: a budget alert at $25 (a $100 monthly budget already exists).

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `InvalidParameterCombination: ... not eligible for Free Tier` | The account is on the free plan and the instance type is not on its list. Use a free-plan type (Before the first apply, step 1) or upgrade the plan. A `run-instances --dry-run` succeeds regardless, so it proves nothing; probe with a real launch and terminate it at once. |
| `VcpuLimitExceeded` | The fleet needs more vCPU than the quota. Reduce `client_count` or request a higher quota. |
| Server container is up but every port is closed, log full of `Accept failed` | The same port listed twice (for example `-port=8080` default plus `-ports=8080-8095`). Fixed in the server: repeats are dropped and the server exits if a port is not accepting after start. |
| Server waits 20 minutes and Prometheus has no client targets | Instances were not found by tag. Spot instances launched through `aws_spot_instance_request` do not get the request's tags; the stack uses `aws_instance` with `instance_market_options` for that reason. |
| Cloud-init fails at `cd .../deploy/aws` | `git_ref` points at a commit without the AWS stack, or was not pushed. |
| Server container missing, cloud-init log ends with `error setting rlimit type 7: operation not permitted` | The container `nofile` limit is above the host `fs.nr_open` (2000000 in cloud-init). Fixed: both compose files use 2000000. |
| New SSH, Prometheus or Grafana connections time out while existing traffic continues; dials `timeout` | Connection-tracking exhaustion: `conntrack_allowance_available` is 0. The security group must be open both ways with the filtering in the network ACL (see above). |
| New SSH, Prometheus or Grafana connections time out, `dmesg` (or the instance's console output) shows `nf_conntrack: table full, dropping packet` | The kernel's connection-tracking table reached `nf_conntrack_max`. Exempt the server ports (done by cloud-init now) or raise the limit; `conntrack -F` empties the table (needs the `conntrack-tools` package). See above. |
| `EntityAlreadyExists` for an IAM role when a second stack is applied | IAM names are account-wide: use `-var iam_name_prefix=<another prefix>`. |
| `docker compose` not found | Amazon Linux 2023 does not package the compose plugin; cloud-init installs v2.29.7. |
| `tofu apply` says `No valid credential sources found` | Credentials are not in the shell. With `aws login`, run `eval "$(aws configure export-credentials --format env)"` in the same shell. |

## Not yet verified on real instances

- Above about 1.42M connections, or with a container above 7 GiB (an 8 GiB instance cannot go much further; a bigger instance needs the paid plan).
- Busy connections: every run used one 32-byte message per connection every 30 seconds.
- Holds longer than about 94 minutes at 1M, and any real (not frozen) stall at 6.5 or 7 GiB.
- The watchdog on a stopped or Spot instance; `scripts/kill-bench.sh`.
