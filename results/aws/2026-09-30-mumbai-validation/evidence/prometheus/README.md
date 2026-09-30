# Prometheus data

- `prometheus_range_1300-1503IST_5s.json`: 20 queries over the whole run at 5 s steps (in git).
- `server_metrics_scrape_1502IST.prom`: one raw scrape of the server's `/metrics` (in git).
- **mumbai-validation_prometheus_tsdb_data_copy.tgz** (6.5 MB): the server's whole Prometheus data directory, taken after stopping the container. Not in git; download it from the release:

https://github.com/meanii/millionws/releases/download/evidence-validation-2026-09-30/mumbai-validation_prometheus_tsdb_data_copy.tgz

SHA-256: `51ba72217b8f4a44efb18894d1cd92431b0287f238e1c59d3f947dca23947428`

To query it: `mkdir data && tar xzf mumbai-validation_prometheus_tsdb_data_copy.tgz -C data && docker run --rm -p 9090:9090 -v "$PWD/data:/prometheus" prom/prometheus:v3.5.0 --storage.tsdb.path=/prometheus --storage.tsdb.retention.time=7d`, with the time range 2026-09-30 07:30 to 09:40 UTC (13:00 to 15:10 IST).

Counters restart with the server, so `millionws_connections_rejected_total` and the other counters go back to 0 after each of the three kills and the restart at 14:12.
