# Local comparison, 2026-09-28

Each variant ran 3 times with the same limits (see environment.md in each run directory).
Values are medians, with the range in brackets.

| Variant | Runs | Peak connections | KiB per connection | Kernel KiB | Go (anon) KiB | CPU near peak | Echo p99 ms | Stopped by |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `gorilla` | 3 | 39,770 (39,692 to 40,694) | 25.11 (25.01 to 25.15) | 4.00 (4.00 to 4.00) | 21.08 (20.97 to 21.14) | 18% (18% to 20%) | 1 (1 to 5) | OOM kill |
| `nbio-initial` | 3 | 193,532 (192,167 to 195,594) | 5.31 (5.31 to 5.38) | 3.96 | 1.35 (1.34 to 1.41) | 34% (33% to 39%) | 15 (12 to 77) | OOM kill |
| `nbio-fixes` | 3 | 194,014 (193,562 to 195,776) | 5.36 (5.33 to 5.37) | 3.96 | 1.40 (1.36 to 1.40) | 36% (35% to 40%) | 15 (12 to 42) | OOM kill |
| `nbio-ipv4` | 3 | 200,694 (199,759 to 201,892) | 5.19 (5.14 to 5.19) | 3.83 | 1.35 (1.30 to 1.35) | 37% (37% to 37%) | 19 (12 to 23) | OOM kill |
| `nbio-memlimit` | 3 | 210,730 (208,509 to 211,789) | 4.93 (4.91 to 4.97) | 3.83 (3.83 to 3.83) | 1.10 (1.08 to 1.13) | 99% (99% to 100%) | 201 (118 to 343) | OOM kill |
| `nbio-guard` | 3 | 180,842 (180,558 to 181,184) | 5.39 (5.39 to 5.40) | 3.84 | 1.55 (1.55 to 1.56) | 43% (42% to 43%) | 24 (23 to 33) | stopped growing, server still up |
| `nbio-tuned` | 3 | 190,894 (190,163 to 191,064) | 4.91 (4.90 to 4.94) | 3.83 (3.83 to 3.84) | 1.08 (1.07 to 1.10) | 98% (94% to 99%) | 93 (92 to 101) | stopped growing, server still up |

Runs:

- `results/local/2026-09-28-gorilla`
- `results/local/2026-09-28-nbio-initial`
- `results/local/2026-09-28-nbio-fixes`
- `results/local/2026-09-28-nbio-ipv4`
- `results/local/2026-09-28-nbio-memlimit`
- `results/local/2026-09-28-nbio-guard`
- `results/local/2026-09-28-nbio-tuned`
- `results/local/2026-09-28-gorilla-2`
- `results/local/2026-09-28-nbio-initial-2`
- `results/local/2026-09-28-nbio-fixes-2`
- `results/local/2026-09-28-nbio-ipv4-2`
- `results/local/2026-09-28-nbio-memlimit-2`
- `results/local/2026-09-28-nbio-guard-2`
- `results/local/2026-09-28-nbio-tuned-2`
- `results/local/2026-09-28-gorilla-3`
- `results/local/2026-09-28-nbio-initial-3`
- `results/local/2026-09-28-nbio-fixes-3`
- `results/local/2026-09-28-nbio-ipv4-3`
- `results/local/2026-09-28-nbio-memlimit-3`
- `results/local/2026-09-28-nbio-guard-3`
- `results/local/2026-09-28-nbio-tuned-3`
