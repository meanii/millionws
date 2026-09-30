# gorilla

Stopped because: server container stopped (exited true 137).

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 40,694 |
| Container memory (cgroup) | 2.9 MiB | 996.6 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.5 MiB | 159.5 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 8.9 MiB | 841.9 MiB |
| Go heap in use | 2.5 MiB | 479.9 MiB |
| Goroutines | 8 | 40,701 |
| Open file descriptors | 9 | 40,703 |
| CPU, average near peak | | 20.2% of one core |
| Echo latency p50 / p99 | | 0 ms / 5 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 25.0 KiB |
| Anonymous memory | 21.0 KiB |
| Kernel memory (socket structs, epoll, slab) | 4.0 KiB |
| of which slab objects | 4.0 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 21.0 KiB |
| Go heap | 12.0 KiB |

Final container state: `exited true 137` (status, OOM-killed, exit code). Highest cgroup memory during the run: 996.9 MiB.

Dial errors by reason: none.
