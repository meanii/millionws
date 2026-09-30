# nbio-fixes

Stopped because: server container stopped (exited true 137).

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 194,014 |
| Container memory (cgroup) | 5.0 MiB | 1,021.5 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 750.9 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 11.2 MiB | 276.1 MiB |
| Go heap in use | 14.0 MiB | 265.9 MiB |
| Goroutines | 15 | 15 |
| Open file descriptors | 15 | 194,029 |
| CPU, average near peak | | 34.9% of one core |
| Echo latency p50 / p99 | | 3 ms / 42 ms |

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

Final container state: `exited true 137` (status, OOM-killed, exit code). Highest cgroup memory during the run: 1,024.4 MiB.

Dial errors by reason: reset 2.
