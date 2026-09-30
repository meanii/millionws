# nbio-tuned

Stopped because: target of 50,000 connections reached and held for 60s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 50,000 |
| Container memory (cgroup) | 6.3 MiB | 538.6 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 188.3 MiB |
| Kernel socket buffers | 0.0 MiB | 144.4 MiB |
| Process RSS | 11.1 MiB | 211.4 MiB |
| Go heap in use | 14.0 MiB | 167.7 MiB |
| Goroutines | 18 | 1,890 |
| Open file descriptors | 15 | 50,015 |
| CPU, average near peak | | 100.0% of one core |
| Echo latency p50 / p99 | | 1,305 ms / 4,249 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 10.9 KiB |
| Anonymous memory | 4.1 KiB |
| Kernel memory (socket structs, epoll, slab) | 3.8 KiB |
| of which slab objects | 3.8 KiB |
| Kernel socket buffers | 3.0 KiB |
| Process RSS | 4.1 KiB |
| Go heap | 3.1 KiB |

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 600.2 MiB.

Dial errors by reason: none.
