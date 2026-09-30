# nbio-tuned

Stopped because: no growth above 190,894 connections for 90s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 190,894 |
| Container memory (cgroup) | 5.9 MiB | 921.9 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 715.5 MiB |
| Kernel socket buffers | 0.0 MiB | 0.3 MiB |
| Process RSS | 10.7 MiB | 211.3 MiB |
| Go heap in use | 13.2 MiB | 201.0 MiB |
| Goroutines | 18 | 84 |
| Open file descriptors | 15 | 190,933 |
| CPU, average near peak | | 99.1% of one core |
| Echo latency p50 / p99 | | 10 ms / 93 ms |

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

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 924.5 MiB.

Dial errors by reason: handshake 89,644.
