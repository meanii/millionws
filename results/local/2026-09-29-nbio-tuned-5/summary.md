# nbio-tuned

Stopped because: target of 100,000 connections reached and held for 60s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 100,000 |
| Container memory (cgroup) | 5.2 MiB | 522.2 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 375.1 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 10.2 MiB | 152.2 MiB |
| Go heap in use | 13.0 MiB | 148.3 MiB |
| Goroutines | 18 | 18 |
| Open file descriptors | 15 | 100,015 |
| CPU, average near peak | | 11.5% of one core |
| Echo latency p50 / p99 | | 1 ms / 3 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 5.3 KiB |
| Anonymous memory | 1.5 KiB |
| Kernel memory (socket structs, epoll, slab) | 3.8 KiB |
| of which slab objects | 3.8 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 1.5 KiB |
| Go heap | 1.4 KiB |

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 522.4 MiB.

Dial errors by reason: none.
