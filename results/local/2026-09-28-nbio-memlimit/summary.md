# nbio-memlimit

Stopped because: server container stopped (exited true 137).

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 211,789 |
| Container memory (cgroup) | 4.8 MiB | 1,024.0 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 793.5 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 10.7 MiB | 236.9 MiB |
| Go heap in use | 13.1 MiB | 226.3 MiB |
| Goroutines | 17 | 31 |
| Open file descriptors | 15 | 211,805 |
| CPU, average near peak | | 98.9% of one core |
| Echo latency p50 / p99 | | 5 ms / 343 ms |

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

Final container state: `exited true 137` (status, OOM-killed, exit code). Highest cgroup memory during the run: 1,024.5 MiB.

Dial errors by reason: reset 2.
