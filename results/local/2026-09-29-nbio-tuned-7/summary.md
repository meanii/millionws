# nbio-tuned

Stopped because: no growth above 190,813 connections for 600s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 190,890 |
| Container memory (cgroup) | 5.4 MiB | 925.8 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 715.7 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 11.4 MiB | 213.8 MiB |
| Go heap in use | 14.0 MiB | 203.2 MiB |
| Goroutines | 18 | 45 |
| Open file descriptors | 15 | 190,920 |
| CPU, average near peak | | 82.2% of one core |
| Echo latency p50 / p99 | | 30 ms / 199 ms |

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

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 934.8 MiB.

Dial errors by reason: handshake 525,309, timeout 14,604.
