# nbio-2ports

Stopped because: target of 100,000 connections reached and held for 60s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 100,000 |
| Container memory (cgroup) | 4.4 MiB | 529.9 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 375.2 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 10.7 MiB | 160.1 MiB |
| Go heap in use | 13.0 MiB | 155.0 MiB |
| Goroutines | 18 | 18 |
| Open file descriptors | 16 | 100,016 |
| CPU, average near peak | | 10.0% of one core |
| Echo latency p50 / p99 | | 3 ms / 11 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 5.4 KiB |
| Anonymous memory | 1.5 KiB |
| Kernel memory (socket structs, epoll, slab) | 3.8 KiB |
| of which slab objects | 3.8 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 1.5 KiB |
| Go heap | 1.5 KiB |

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 530.9 MiB.

Dial errors by reason: none.
