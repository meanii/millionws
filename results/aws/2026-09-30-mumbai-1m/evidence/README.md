# Evidence for the Mumbai run (all times IST)

What each file is and how it was made. The analysis and the numbers are in [../README.md](../README.md). Text files were scanned for the account ID, access keys, the operator's IP and local paths before being committed, and the terminal recording's header (which stored the SSH command line) was redacted. The instances no longer exist.

| Path | What it is |
| --- | --- |
| `video/grafana-1m-ramp-crash-recovery_2026-09-30_1025-1037IST.mp4` (**in the [release](https://github.com/meanii/millionws/releases/tag/evidence-mumbai-2026-09-30), not in git**, see `video/README.md`) | 11 minutes, 1280x890, of the live Grafana dashboard `MillionWS local bench` (5 s refresh) recorded with Playwright. It starts mid-ramp, shows 1M connections, the first OOM kill at 10:31:18 and the recovery. Re-encoded from the original WebM (33 MB) to H.264. |
| `video/frame_*.png` | still frames from the video at 60 s, 300 s, 335 s, 420 s and 560 s after its start (start about 10:25:45) |
| `terminal/live-view_1025-1036IST.cast` | asciinema recording (`asciinema play <file>`) of the server's live view: connections, sockets, memory, ENA counters, container stats. It includes the ramp from 104,597 connections and the first kill (999,996 to 55,977 at second 386). The header was redacted. |
| `terminal/terminal-live-view_1025-1036IST_8x.gif` | the same recording rendered as a GIF at 8x with `agg` |
| `screenshots/grafana_*_full-run_1022-1139IST.png` | the two repo dashboards over the whole run 10:22 to 11:39, showing all three drops. The second dashboard includes the loadgen jobs, so its memory panels have several series. |
| `screenshots/scheduled_shot-*.png` | screenshots every 90 s during the video recording (file names are the IST time) |
| `charts/timeline_overview_IST.png`, `charts/third_kill_1hz_IST.png` | drawn from the raw data by `scripts/evidence/plot_run.py`: connections, container memory against the limit and the guard, echo p99; and the 1 s trace of the third kill |
| `prometheus/prometheus_range_1022-1139IST_5s.json` | 20 queries exported at 5 s steps over the whole run (connections per replica, dial errors by reason, rates, latency quantiles, process memory, goroutines, file descriptors, scrape health) |
| `prometheus/prometheus_tsdb_data_copy.tgz` (**in the [release](https://github.com/meanii/millionws/releases/tag/evidence-mumbai-2026-09-30), not in git**, see `prometheus/README.md`) | copy of the server's Prometheus data directory (4.5 MB) taken after stopping the Prometheus container; load it into a Prometheus of the same major version to query anything else |
| `prometheus/server_metrics_scrape_1139IST.prom` | one raw scrape of the server's `/metrics` |
| `hosts/*_sampler_10s.csv` | per-host CSV written by `scripts/evidence/sampler.sh` every 10 s from boot: established sockets, memory, kernel slab, container memory, ENA counters. **The `cpu_pct` column is wrong** (it ignores softirq and steal time; fixed in the script after the run). |
| `hosts/*_snapshot_*.txt` | `scripts/evidence/host_snapshot.sh` output for the server and each client at 10:31 (`at-crash1`, taken at the moment of the first kill), 11:09 (`steady`), 11:25 (`replay-WITHOUT-pprof`) and 11:39 (`final`) |
| `hosts/*_cloud-init.log` | cloud-init output, showing the pinned commit and the start-up |
| `kernel/dmesg_oom_kills_3.txt` | the kernel's three OOM reports with the memory-cgroup breakdown |
| `kernel/server_container_status_and_log.txt` | the container's restart count and the server log (guard messages, restarts) |
| `kernel/memwatch_1hz_30s-cpu-profile-crash_1133IST.csv` | 1 Hz container memory (total, anon, sock, kernel) and established sockets around the third kill |
| `kernel/memwatch_1hz_reramp_after_crash2_1109IST.csv` | the same logger during the re-ramp after the second kill (a test of `ss -tin` that turned out not to matter) |
| `pprof/*.pb.gz` | heap and goroutine profiles at about 1M connections (10:31:04 and 11:07:38) and a CPU profile. Open with `go tool pprof`. The 10:31 CPU profile is timestamped 10:31:29, after the restart. |
| `experiments/bisect_actions_1113-1124IST.log` | the log of the one-action-at-a-time tests, and `repro_cpu30s_1133IST.log` for the deliberate reproduction |
| `experiments/host_snapshot_safe.sh` | the snapshot script used for those tests (without the `/proc/slabinfo` read) |
| `aws/cloudtrail_mumbai_timeline_IST.csv` | CloudTrail events in ap-south-1: key import, quota request, launches, terminations, Lambda and network ACL creation |
| `aws/cloudwatch/mumbai_*.json` | CloudWatch CPU and network metrics, 5 minute averages, for the four instances |

## What is missing or weak

- The video does not cover the third kill or the last half hour; the terminal recording ends at 10:36. The Grafana screenshots and the raw Prometheus data cover everything.
- The 1 Hz memory logger did not run during the one-action tests; only the 11:33 reproduction and the 11:09 re-ramp have 1 Hz data.
- `aws/cloudtrail_mumbai_timeline_IST.csv` has no destroy events for the network ACL and Lambda functions because CloudTrail had not delivered them when I pulled it.
- CloudWatch has one datapoint per 5 minutes; it says the instances ran and carried traffic, not how many connections they held.
