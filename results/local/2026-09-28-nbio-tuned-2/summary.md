# nbio-tuned

Stopped because: no growth above 191,064 connections for 90s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 191,064 |
| Container memory (cgroup) | 5.9 MiB | 920.8 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 716.2 MiB |
| Kernel socket buffers | 0.0 MiB | 0.5 MiB |
| Process RSS | 10.6 MiB | 209.0 MiB |
| Go heap in use | 13.2 MiB | 200.5 MiB |
| Goroutines | 18 | 111 |
| Open file descriptors | 15 | 191,110 |
| CPU, average near peak | | 98.5% of one core |
| Echo latency p50 / p99 | | 14 ms / 92 ms |

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

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 925.1 MiB.

Dial errors by reason: handshake 89,263.
