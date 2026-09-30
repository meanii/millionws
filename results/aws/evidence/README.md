# Evidence for the AWS runs of 2026-09-30

Files that back the numbers in the [run reports](../). Text files were scanned for the account ID, access keys, the operator's IP and local paths before being committed; the operator IP is shown as `<operator>` where it matters. The EC2 instances and their public IPs no longer exist.

## Which run each file belongs to

| Run | Report | Evidence available |
| --- | --- | --- |
| First canary (76,952, stopped by connection tracking) | [report](../2026-09-30-canary/README.md) | AWS-side records only (CloudTrail, CloudWatch). Its measurements were read live over SSH and are in the report; no raw files were kept. |
| 250,000 on one client | [report](../2026-09-30-250k/README.md) | AWS-side records, the network probe, `earlier-runs/250k-run_reached-250000.txt`. Measurements are in the report; no raw files were kept. |
| First 1M run (999,999) | [report](../2026-09-30-1m/README.md) | AWS-side records and two saved Prometheus query outputs (`earlier-runs/`). No screenshots or time series: that stack was destroyed before anything was exported. |
| **Repeat 1M run (999,996)** | [report](../2026-09-30-1m-repeat/README.md) | Everything below: screenshots, Prometheus history, snapshots of all four hosts, AWS-side records. |

## Files

| Path | What it is | What it shows |
| --- | --- | --- |
| `grafana/1m-hold-dashboard-local-bench.png` | Grafana dashboard `MillionWS local bench` on the repeat run, 03:39:30 to 03:59:32 UTC | active connections climbing to 1,000,000 and flat; 48 disconnects; memory, Go heap sawtooth, open file descriptors |
| `grafana/1m-hold-dashboard-millionws-all-jobs.png` | Grafana dashboard `MillionWS` on the same run, to 04:00:18 | the same panels with all jobs, so the loadgen processes appear as extra series |
| `prometheus/prometheus_range.json` | 19 queries exported at 10 s steps, 03:39:30 to 04:00:49 | connections (server and each loadgen replica), rejections, upgrade errors, dial errors, message rates, echo latency p50 and p99, RSS, heap, file descriptors, goroutines, scrape health |
| `prometheus/server_metrics_scrape_at_hold.prom` | One raw scrape of the server's `/metrics` during the hold | the metrics exactly as exported, including Go and process collectors |
| `hosts/*_snapshot.txt` | System snapshot of the server and each of the three clients at about 03:54 | commit SHA, instance type, kernel, memory, `ss -s` socket counts, sysctls, containers, ENA allowance counters |
| `hosts/server_last_sample_04-01Z.txt` | Last direct sample of the server before destroy | cgroup memory, RSS, ENA `pps` and `conntrack` counters |
| `hosts/server_memory_samples_TRANSCRIBED.txt` | Container memory breakdown (anon, slab, sock) | 3.83 KiB of kernel slab per connection. **Transcribed by hand** from the terminal: the output was not saved as a file. |
| `hosts/*_cloud-init.log` | cloud-init output of the server and one client | package installs, git checkout at the pinned commit, compose start |
| `aws/cloudtrail_timeline.csv` | CloudTrail events for the day: every `RunInstances` (including refused ones), `TerminateInstances`, Lambda and network ACL create and delete | independent launch and terminate times and instance IDs for all runs; the early refusals with `Client.InvalidParameterCombination` |
| `aws/cloudwatch/*.json` | CloudWatch EC2 metrics, 5 minute averages, for the instances of every run | CPU and network in and out, from AWS, independent of the instances |
| `network/nacl_rules.txt` | The network ACL and security group rules | the filtering that replaced the tracked security group |
| `network/nacl_outside_probe_TRANSCRIBED.txt` | Result of probing the server's ports from a Lambda function outside the operator's IP | the ports the ACL blocks. **Transcribed by hand**: the probe function and its output file were deleted. |
| `earlier-runs/` | Query outputs saved during the first 1M run and the 250k run | see the file names; the 03:23 file is a ramp-time sample and is not a settled reading |

## What the evidence cannot show

- **Only the repeat run has a full record.** The first canary, the 250k run and the first 1M run are backed by the reports, CloudTrail and CloudWatch, not by exported time series or screenshots.
- **CloudWatch metrics are 5 minute averages** and cover only what a 5 minute period can show; they confirm the instances ran and carried traffic, not connection counts.
- **The Grafana screenshots are of the live dashboards** on that stack; their panel titles and units are the dashboards' own, and I did not change them. Some panel titles are misleading: for example "process memory deriv" shows the rate of change.
- **Two files are transcribed** (marked `TRANSCRIBED`), because the raw output was not saved.
- **The ENA counters** in the snapshots are cumulative since boot; they do not say when a counter increased.

## Reproducing the checks

- Compare the reports' numbers with `prometheus/prometheus_range.json` (Python: `json.load`, then `series[<name>]["result"][0]["values"]` as `[unix_time, value]` pairs).
- Instance launch and termination times: `aws/cloudtrail_timeline.csv`, filtered on `RunInstances` and `TerminateInstances`.
