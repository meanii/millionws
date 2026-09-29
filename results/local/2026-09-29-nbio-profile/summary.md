# nbio-profile

Stopped because: no growth above 189,480 connections for 90s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 190,365 |
| Container memory (cgroup) | 5.1 MiB | 923.6 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 713.7 MiB |
| Kernel socket buffers | 0.0 MiB | 0.4 MiB |
| Process RSS | 10.4 MiB | 214.9 MiB |
| Go heap in use | 12.9 MiB | 205.2 MiB |
| Goroutines | 17 | 275 |
| Open file descriptors | 15 | 190,443 |
| CPU, average near peak | | 91.9% of one core |
| Echo latency p50 / p99 | | 19 ms / 179 ms |

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

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 930.0 MiB.

Dial errors by reason: handshake 87,232.
