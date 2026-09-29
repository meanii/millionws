# nbio-tuned

Stopped because: no growth above 95,887 connections for 90s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 95,887 |
| Container memory (cgroup) | 5.8 MiB | 462.4 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 359.8 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 11.7 MiB | 108.3 MiB |
| Go heap in use | 14.1 MiB | 103.5 MiB |
| Goroutines | 17 | 135 |
| Open file descriptors | 15 | 95,950 |
| CPU, average near peak | | 99.8% of one core |
| Echo latency p50 / p99 | | 12 ms / 98 ms |

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

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 464.4 MiB.

Dial errors by reason: handshake 87,417.
