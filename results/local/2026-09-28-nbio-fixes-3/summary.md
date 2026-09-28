# nbio-fixes

Stopped because: server container stopped (exited true 137).

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 193,562 |
| Container memory (cgroup) | 5.5 MiB | 1,019.0 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 749.2 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 11.4 MiB | 275.1 MiB |
| Go heap in use | 13.9 MiB | 265.7 MiB |
| Goroutines | 16 | 54 |
| Open file descriptors | 15 | 193,577 |
| CPU, average near peak | | 35.9% of one core |
| Echo latency p50 / p99 | | 2 ms / 12 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 5.4 KiB |
| Anonymous memory | 1.4 KiB |
| Kernel memory (socket structs, epoll, slab) | 4.0 KiB |
| of which slab objects | 4.0 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 1.4 KiB |
| Go heap | 1.3 KiB |

Final container state: `exited true 137` (status, OOM-killed, exit code). Highest cgroup memory during the run: 1,024.2 MiB.

Dial errors by reason: none.
