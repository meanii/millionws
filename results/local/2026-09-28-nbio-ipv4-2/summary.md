# nbio-ipv4

Stopped because: server container stopped (exited true 137).

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 201,892 |
| Container memory (cgroup) | 6.1 MiB | 1,019.4 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 756.6 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 11.2 MiB | 267.9 MiB |
| Go heap in use | 13.9 MiB | 246.6 MiB |
| Goroutines | 16 | 16 |
| Open file descriptors | 15 | 201,907 |
| CPU, average near peak | | 36.7% of one core |
| Echo latency p50 / p99 | | 2 ms / 12 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 5.1 KiB |
| Anonymous memory | 1.3 KiB |
| Kernel memory (socket structs, epoll, slab) | 3.8 KiB |
| of which slab objects | 3.8 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 1.3 KiB |
| Go heap | 1.2 KiB |

Final container state: `exited true 137` (status, OOM-killed, exit code). Highest cgroup memory during the run: 1,024.4 MiB.

Dial errors by reason: none.
