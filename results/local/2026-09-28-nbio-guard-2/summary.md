# nbio-guard

Stopped because: no growth above 180,784 connections for 90s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 181,184 |
| Container memory (cgroup) | 5.5 MiB | 959.4 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 679.4 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 11.1 MiB | 285.6 MiB |
| Go heap in use | 14.1 MiB | 260.9 MiB |
| Goroutines | 18 | 18 |
| Open file descriptors | 15 | 181,199 |
| CPU, average near peak | | 43.1% of one core |
| Echo latency p50 / p99 | | 3 ms / 33 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 5.4 KiB |
| Anonymous memory | 1.6 KiB |
| Kernel memory (socket structs, epoll, slab) | 3.8 KiB |
| of which slab objects | 3.8 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 1.6 KiB |
| Go heap | 1.4 KiB |

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 961.0 MiB.

Dial errors by reason: handshake 86,651.
