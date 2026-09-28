# nbio-memlimit

Stopped because: server container stopped (exited true 137).

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 210,730 |
| Container memory (cgroup) | 6.1 MiB | 1,017.2 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 789.6 MiB |
| Kernel socket buffers | 0.0 MiB | 0.2 MiB |
| Process RSS | 11.4 MiB | 233.1 MiB |
| Go heap in use | 13.9 MiB | 222.9 MiB |
| Goroutines | 17 | 96 |
| Open file descriptors | 15 | 210,759 |
| CPU, average near peak | | 98.6% of one core |
| Echo latency p50 / p99 | | 4 ms / 118 ms |

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

Final container state: `exited true 137` (status, OOM-killed, exit code). Highest cgroup memory during the run: 1,024.3 MiB.

Dial errors by reason: none.
