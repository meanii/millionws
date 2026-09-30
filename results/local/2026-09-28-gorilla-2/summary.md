# gorilla

Stopped because: server container stopped (exited true 137).

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 39,692 |
| Container memory (cgroup) | 4.2 MiB | 979.1 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.5 MiB | 155.6 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 9.4 MiB | 828.0 MiB |
| Go heap in use | 2.7 MiB | 474.7 MiB |
| Goroutines | 7 | 39,699 |
| Open file descriptors | 9 | 39,701 |
| CPU, average near peak | | 17.6% of one core |
| Echo latency p50 / p99 | | 0 ms / 1 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 25.2 KiB |
| Anonymous memory | 21.1 KiB |
| Kernel memory (socket structs, epoll, slab) | 4.0 KiB |
| of which slab objects | 4.0 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 21.1 KiB |
| Go heap | 12.2 KiB |

Final container state: `exited true 137` (status, OOM-killed, exit code). Highest cgroup memory during the run: 1,024.0 MiB.

Dial errors by reason: refused 16, reset 126.
