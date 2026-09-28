# nbio-guard

Stopped because: no growth above 180,836 connections for 90s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 180,842 |
| Container memory (cgroup) | 4.7 MiB | 957.9 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 678.2 MiB |
| Kernel socket buffers | 0.0 MiB | 0.1 MiB |
| Process RSS | 10.3 MiB | 285.3 MiB |
| Go heap in use | 12.9 MiB | 263.6 MiB |
| Goroutines | 17 | 58 |
| Open file descriptors | 15 | 180,858 |
| CPU, average near peak | | 41.9% of one core |
| Echo latency p50 / p99 | | 3 ms / 23 ms |

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

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 959.6 MiB.

Dial errors by reason: handshake 87,996.
