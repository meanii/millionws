# Environment

| Item | Value |
| --- | --- |
| Date | 2026-09-29 09:15 UTC |
| Variant | `nbio-2ports` |
| Server code | `99d9237` |
| Harness commit | `99d9237` |
| Server limits | 1 CPU, 1g memory, no swap, nofile 1048576 |
| Server tuning | GOMEMLIMIT=`unset`, GOGC=`unset` |
| Load generators | 1 containers x 100000 connections, 1000 dials/s each |
| Messages | 32 bytes every 30s per connection |
| Host CPU | AMD Ryzen 5 5600F 6-Core Processor, 12 threads |
| Host memory | 39 GiB |
| Kernel | 7.0.0-34-generic |
| Docker | 29.8.1 |
| Docker mode | rootless |
| Docker network nf_conntrack_max | 262144 |
