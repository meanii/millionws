# nbio-tuned

Stopped because: no growth above 189,941 connections for 90s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 189,941 |
| Container memory (cgroup) | 5.3 MiB | 925.0 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 712.6 MiB |
| Kernel socket buffers | 0.0 MiB | 0.5 MiB |
| Process RSS | 11.2 MiB | 217.7 MiB |
| Go heap in use | 13.6 MiB | 206.6 MiB |
| Goroutines | 17 | 35 |
| Open file descriptors | 15 | 190,033 |
| CPU, average near peak | | 173.8% of one core |
| Echo latency p50 / p99 | | 19 ms / 188 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 5.0 KiB |
| Anonymous memory | 1.1 KiB |
| Kernel memory (socket structs, epoll, slab) | 3.8 KiB |
| of which slab objects | 3.8 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 1.1 KiB |
| Go heap | 1.0 KiB |

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 929.4 MiB.

Dial errors by reason: handshake 87,770.
