# Prometheus data

- `prometheus_range_1306-1444IST_5s.json`: 20 queries from 13:06 to 14:44 at 5 s steps (in git).
- `server_metrics_scrape_1426IST.prom`: one raw scrape of the server's `/metrics` (in git).
- **virginia-hold_prometheus_tsdb_data_copy.tgz** (5.2 MB): the server's whole Prometheus data directory. Not in git; download it from the release:

https://github.com/meanii/millionws/releases/download/evidence-validation-2026-09-30/virginia-hold_prometheus_tsdb_data_copy.tgz

SHA-256: `f2442cf0b6c91ab8d6a7d8b23e71e027688698faa472ae9cbdf52c186ed806b2`

To query it: `mkdir data && tar xzf virginia-hold_prometheus_tsdb_data_copy.tgz -C data && docker run --rm -p 9090:9090 -v "$PWD/data:/prometheus" prom/prometheus:v3.5.0 --storage.tsdb.path=/prometheus --storage.tsdb.retention.time=7d`, with the time range 2026-09-30 07:36 to 09:15 UTC (13:06 to 14:45 IST).
