# nbio-fixes

Stopped because: target of 120,000 connections reached and held for 60s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 120,000 |
| Container memory (cgroup) | 4.2 MiB | 655.3 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 464.5 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 10.8 MiB | 196.8 MiB |
| Go heap in use | 12.9 MiB | 161.7 MiB |
| Goroutines | 16 | 210 |
| Open file descriptors | 15 | 120,015 |
| CPU, average near peak | | 12.6% of one core |
| Echo latency p50 / p99 | | 3 ms / 11 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 5.6 KiB |
| Anonymous memory | 1.6 KiB |
| Kernel memory (socket structs, epoll, slab) | 4.0 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 1.6 KiB |
| Go heap | 1.3 KiB |

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 657.4 MiB.

Dial errors by reason: none.
