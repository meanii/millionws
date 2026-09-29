# nbio-pollers1

Stopped because: no growth above 191,962 connections for 90s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 191,962 |
| Container memory (cgroup) | 4.9 MiB | 924.5 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.6 MiB | 719.6 MiB |
| Kernel socket buffers | 0.0 MiB | 0.9 MiB |
| Process RSS | 10.5 MiB | 209.8 MiB |
| Go heap in use | 12.9 MiB | 200.5 MiB |
| Goroutines | 16 | 42 |
| Open file descriptors | 11 | 192,093 |
| CPU, average near peak | | 94.4% of one core |
| Echo latency p50 / p99 | | 28 ms / 156 ms |

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

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 929.6 MiB.

Dial errors by reason: handshake 86,257.
