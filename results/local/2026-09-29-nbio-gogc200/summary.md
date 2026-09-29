# nbio-gogc200

Stopped because: no growth above 184,087 connections for 90s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 184,087 |
| Container memory (cgroup) | 6.0 MiB | 926.6 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 690.8 MiB |
| Kernel socket buffers | 0.0 MiB | 0.9 MiB |
| Process RSS | 11.5 MiB | 239.7 MiB |
| Go heap in use | 14.1 MiB | 228.6 MiB |
| Goroutines | 18 | 131 |
| Open file descriptors | 15 | 184,197 |
| CPU, average near peak | | 80.7% of one core |
| Echo latency p50 / p99 | | 47 ms / 367 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 5.1 KiB |
| Anonymous memory | 1.3 KiB |
| Kernel memory (socket structs, epoll, slab) | 3.8 KiB |
| of which slab objects | 3.8 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 1.3 KiB |
| Go heap | 1.2 KiB |

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 939.9 MiB.

Dial errors by reason: handshake 85,135.
