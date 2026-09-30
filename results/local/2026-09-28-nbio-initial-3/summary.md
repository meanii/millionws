# nbio-initial

Stopped because: server container stopped (exited true 137).

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 193,532 |
| Container memory (cgroup) | 5.6 MiB | 1,010.0 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 749.0 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 10.8 MiB | 265.9 MiB |
| Go heap in use | 13.9 MiB | 257.7 MiB |
| Goroutines | 15 | 15 |
| Open file descriptors | 15 | 193,548 |
| CPU, average near peak | | 34.3% of one core |
| Echo latency p50 / p99 | | 2 ms / 12 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 5.3 KiB |
| Anonymous memory | 1.4 KiB |
| Kernel memory (socket structs, epoll, slab) | 4.0 KiB |
| of which slab objects | 4.0 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 1.3 KiB |
| Go heap | 1.3 KiB |

Final container state: `exited true 137` (status, OOM-killed, exit code). Highest cgroup memory during the run: 1,024.4 MiB.

Dial errors by reason: refused 6, reset 200.
