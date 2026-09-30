# nbio-ipv4

Stopped because: server container stopped (exited true 137).

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 199,759 |
| Container memory (cgroup) | 5.4 MiB | 1,018.0 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 748.7 MiB |
| Kernel socket buffers | 0.0 MiB | 0.0 MiB |
| Process RSS | 11.4 MiB | 274.3 MiB |
| Go heap in use | 14.0 MiB | 239.5 MiB |
| Goroutines | 15 | 38 |
| Open file descriptors | 15 | 199,775 |
| CPU, average near peak | | 36.7% of one core |
| Echo latency p50 / p99 | | 2 ms / 19 ms |

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

Dial errors by reason: reset 1.
