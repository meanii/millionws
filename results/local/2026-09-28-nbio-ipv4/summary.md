# nbio-ipv4

Stopped because: server container stopped (exited true 137).

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 200,694 |
| Container memory (cgroup) | 4.1 MiB | 1,021.3 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 752.1 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 10.6 MiB | 274.2 MiB |
| Go heap in use | 13.0 MiB | 240.2 MiB |
| Goroutines | 16 | 16 |
| Open file descriptors | 15 | 200,709 |
| CPU, average near peak | | 37.3% of one core |
| Echo latency p50 / p99 | | 2 ms / 23 ms |

Memory per connection, (peak - idle) / connections:

| Source | Per connection |
| --- | --- |
| Container total (cgroup) | 5.2 KiB |
| Anonymous memory | 1.3 KiB |
| Kernel memory (socket structs, epoll, slab) | 3.8 KiB |
| of which slab objects | 3.8 KiB |
| Kernel socket buffers | 0.0 KiB |
| Process RSS | 1.3 KiB |
| Go heap | 1.2 KiB |

Final container state: `exited true 137` (status, OOM-killed, exit code). Highest cgroup memory during the run: 1,024.3 MiB.

Dial errors by reason: none.
