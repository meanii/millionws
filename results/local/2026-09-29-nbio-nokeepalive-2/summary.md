# nbio-nokeepalive

Stopped because: no growth above 203,716 connections for 90s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 203,716 |
| Container memory (cgroup) | 5.2 MiB | 921.0 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 763.4 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 10.5 MiB | 163.1 MiB |
| Go heap in use | 13.2 MiB | 154.0 MiB |
| Goroutines | 17 | 18 |
| Open file descriptors | 15 | 203,760 |
| CPU, average near peak | | 95.9% of one core |
| Echo latency p50 / p99 | | 13 ms / 95 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 4.6 KiB |
| Anonymous memory | 0.8 KiB |
| Kernel memory (socket structs, epoll, slab) | 3.8 KiB |
| of which slab objects | 3.8 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 0.8 KiB |
| Go heap | 0.7 KiB |

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 926.8 MiB.

Dial errors by reason: handshake 83,034.
