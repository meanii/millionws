# nbio-tuned

Stopped because: no growth above 189,416 connections for 90s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 190,163 |
| Container memory (cgroup) | 6.1 MiB | 922.9 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 713.0 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 11.7 MiB | 215.9 MiB |
| Go heap in use | 14.1 MiB | 204.8 MiB |
| Goroutines | 17 | 26 |
| Open file descriptors | 15 | 190,199 |
| CPU, average near peak | | 94.2% of one core |
| Echo latency p50 / p99 | | 19 ms / 101 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 4.9 KiB |
| Anonymous memory | 1.1 KiB |
| Kernel memory (socket structs, epoll, slab) | 3.8 KiB |
| of which slab objects | 3.8 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 1.1 KiB |
| Go heap | 1.0 KiB |

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 925.8 MiB.

Dial errors by reason: handshake 85,515.
