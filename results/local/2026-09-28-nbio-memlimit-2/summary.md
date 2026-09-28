# nbio-memlimit

Stopped because: server container stopped (exited true 137).

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 208,509 |
| Container memory (cgroup) | 5.1 MiB | 1,016.3 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 781.1 MiB |
| Kernel socket buffers | 0.0 MiB | 1.1 MiB |
| Process RSS | 11.0 MiB | 241.9 MiB |
| Go heap in use | 13.1 MiB | 229.8 MiB |
| Goroutines | 17 | 407 |
| Open file descriptors | 15 | 208,520 |
| CPU, average near peak | | 99.6% of one core |
| Echo latency p50 / p99 | | 3 ms / 201 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 5.0 KiB |
| Anonymous memory | 1.1 KiB |
| Kernel memory (socket structs, epoll, slab) | 3.8 KiB |
| of which slab objects | 3.8 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 1.1 KiB |
| Go heap | 1.1 KiB |

Final container state: `exited true 137` (status, OOM-killed, exit code). Highest cgroup memory during the run: 1,024.4 MiB.

Dial errors by reason: reset 4.
