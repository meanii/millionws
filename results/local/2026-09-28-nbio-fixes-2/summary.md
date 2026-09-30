# nbio-fixes

Stopped because: server container stopped (exited true 137).

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 195,776 |
| Container memory (cgroup) | 5.7 MiB | 1,023.8 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 757.7 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 11.4 MiB | 271.4 MiB |
| Go heap in use | 13.9 MiB | 262.8 MiB |
| Goroutines | 16 | 16 |
| Open file descriptors | 15 | 195,791 |
| CPU, average near peak | | 39.5% of one core |
| Echo latency p50 / p99 | | 3 ms / 15 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 5.3 KiB |
| Anonymous memory | 1.4 KiB |
| Kernel memory (socket structs, epoll, slab) | 4.0 KiB |
| of which slab objects | 4.0 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 1.4 KiB |
| Go heap | 1.3 KiB |

Final container state: `exited true 137` (status, OOM-killed, exit code). Highest cgroup memory during the run: 1,024.6 MiB.

Dial errors by reason: reset 4.
