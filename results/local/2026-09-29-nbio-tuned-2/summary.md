# nbio-tuned

Stopped because: no growth above 191,560 connections for 90s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 191,560 |
| Container memory (cgroup) | 6.6 MiB | 926.5 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 718.2 MiB |
| Kernel socket buffers | 0.0 MiB | 0.1 MiB |
| Process RSS | 11.5 MiB | 213.2 MiB |
| Go heap in use | 14.1 MiB | 203.3 MiB |
| Goroutines | 17 | 20 |
| Open file descriptors | 15 | 191,595 |
| CPU, average near peak | | 94.0% of one core |
| Echo latency p50 / p99 | | 24 ms / 166 ms |

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

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 931.0 MiB.

Dial errors by reason: handshake 88,563.
