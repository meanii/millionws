# Environment

| Item | Value |
| --- | --- |
| Date | 2026-09-29 01:49 UTC |
| Variant | `nbio-tuned` |
| Server code | `476f773` |
| Harness commit | `bb8dfdb` |
| Server limits | 1 CPU, 1g memory, no swap, nofile 1048576 |
| Server tuning | GOMEMLIMIT=`unset`, GOGC=`unset` |
| Load generators | 2 containers x 25000 connections, 500 dials/s each |
| Messages | 1024 bytes every 1s per connection |
| Host CPU | AMD Ryzen 5 5600F 6-Core Processor, 12 threads |
| Host memory | 39 GiB |
| Kernel | 7.0.0-34-generic |
| Docker | 29.8.1 |
| Docker mode | rootless |
| Docker network nf_conntrack_max | 262144 |
