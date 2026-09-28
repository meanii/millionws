# nbio-tuned

Stopped because: no growth above 190,597 connections for 90s.

| Metric | Idle | At peak |
| --- | --- | --- |
| Connections | 0 | 190,764 |
| Container memory (cgroup) | 6.0 MiB | 923.9 MiB |
| Kernel memory (socket structs, epoll, slab) | 0.7 MiB | 715.2 MiB |
| Kernel socket buffers | 0.0 MiB | 0.4 MiB |
| Process RSS | 10.5 MiB | 213.6 MiB |
| Go heap in use | 13.3 MiB | 202.8 MiB |
| Goroutines | 17 | 29 |
| Open file descriptors | 15 | 190,795 |
| CPU, average near peak | | 88.2% of one core |
| Echo latency p50 / p99 | | 27 ms / 200 ms |

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

Final container state: `running false 0` (status, OOM-killed, exit code). Highest cgroup memory during the run: 929.0 MiB.

Dial errors by reason: handshake 87,190.
