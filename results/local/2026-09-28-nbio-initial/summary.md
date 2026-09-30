# nbio-initial

Stopped because: server container stopped (exited true 137).

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 192,167 |
| Container memory (cgroup) | 4.4 MiB | 1,014.3 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 743.8 MiB |
| Kernel socket buffers | 0.0 MiB | 0.3 MiB |
| Process RSS | 10.1 MiB | 274.9 MiB |
| Go heap in use | 13.2 MiB | 265.3 MiB |
| Goroutines | 15 | 136 |
| Open file descriptors | 15 | 192,187 |
| CPU, average near peak | | 33.0% of one core |
| Echo latency p50 / p99 | | 10 ms / 77 ms |

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

Final container state: `exited true 137` (status, OOM-killed, exit code). Highest cgroup memory during the run: 1,024.5 MiB.

Dial errors by reason: reset 3.
