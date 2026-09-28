# nbio-initial

Stopped because: server container stopped (exited true 137).

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 195,594 |
| Container memory (cgroup) | 5.5 MiB | 1,018.8 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 757.0 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 10.1 MiB | 266.6 MiB |
| Go heap in use | 13.1 MiB | 258.9 MiB |
| Goroutines | 15 | 45 |
| Open file descriptors | 15 | 195,609 |
| CPU, average near peak | | 38.8% of one core |
| Echo latency p50 / p99 | | 2 ms / 15 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 5.3 KiB |
| Anonymous memory | 1.3 KiB |
| Kernel memory (socket structs, epoll, slab) | 4.0 KiB |
| of which slab objects | 4.0 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 1.3 KiB |
| Go heap | 1.3 KiB |

Final container state: `exited true 137` (status, OOM-killed, exit code). Highest cgroup memory during the run: 1,024.5 MiB.

Dial errors by reason: refused 22, reset 200.
