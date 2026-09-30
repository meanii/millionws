# nbio-nokeepalive

Stopped because: no growth above 203,654 connections for 90s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 203,648 |
| Container memory (cgroup) | 5.8 MiB | 924.6 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 763.2 MiB |
| Kernel socket buffers | 0.0 MiB | 0.3 MiB |
| Process RSS | 10.6 MiB | 166.5 MiB |
| Go heap in use | 13.3 MiB | 155.5 MiB |
| Goroutines | 18 | 20 |
| Open file descriptors | 15 | 203,683 |
| CPU, average near peak | | 88.0% of one core |
| Echo latency p50 / p99 | | 24 ms / 153 ms |

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

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 934.1 MiB.

Dial errors by reason: handshake 88,223.
