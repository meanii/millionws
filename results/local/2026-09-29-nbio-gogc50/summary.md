# nbio-gogc50

Stopped because: no growth above 194,052 connections for 90s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 194,448 |
| Container memory (cgroup) | 6.0 MiB | 927.4 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 728.9 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 11.4 MiB | 204.3 MiB |
| Go heap in use | 13.2 MiB | 195.1 MiB |
| Goroutines | 17 | 140 |
| Open file descriptors | 15 | 194,532 |
| CPU, average near peak | | 84.3% of one core |
| Echo latency p50 / p99 | | 41 ms / 338 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 4.9 KiB |
| Anonymous memory | 1.0 KiB |
| Kernel memory (socket structs, epoll, slab) | 3.8 KiB |
| of which slab objects | 3.8 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 1.0 KiB |
| Go heap | 1.0 KiB |

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 936.1 MiB.

Dial errors by reason: handshake 83,227.
