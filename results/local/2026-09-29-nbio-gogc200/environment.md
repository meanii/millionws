# Environment

| Item | Value |
| --- | --- |
| Date | 2026-09-29 01:35 UTC |
| Variant | `nbio-gogc200` |
| Server code | `476f773` |
| Harness commit | `bb8dfdb` |
| Server limits | 1 CPU, 1g memory, no swap, nofile 1048576 |
| Server tuning | GOMEMLIMIT=`unset`, GOGC=`200` |
| Load generators | 5 containers x 60000 connections, 200 dials/s each |
| Messages | 32 bytes every 30s per connection |
| Host CPU | AMD Ryzen 5 5600F 6-Core Processor, 12 threads |
| Host memory | 39 GiB |
| Kernel | 7.0.0-34-generic |
| Docker | 29.8.1 |
| Docker mode | rootless |
| Docker network nf_conntrack_max | 262144 |
