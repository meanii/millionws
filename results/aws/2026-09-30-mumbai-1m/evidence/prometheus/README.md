# Prometheus data

- `prometheus_range_1022-1139IST_5s.json`: 20 queries over the whole run at 5 s steps (in git).
- `server_metrics_scrape_1139IST.prom`: one raw scrape of the server's `/metrics` (in git).
- **prometheus_tsdb_data_copy.tgz** (4.5 MB): the server's whole Prometheus data directory, taken after stopping the container. Not stored in git; download it from the release:

https://github.com/meanii/millionws/releases/download/evidence-mumbai-2026-09-30/prometheus_tsdb_data_copy.tgz

SHA-256: `4d243feded90b4252991a0eef2b1a3ed3cf6884671f7a3bab62844266aafdeba`

To query it: `mkdir data && tar xzf prometheus_tsdb_data_copy.tgz -C data && docker run --rm -p 9090:9090 -v "$PWD/data:/prometheus" prom/prometheus:v3.5.0 --storage.tsdb.path=/prometheus --storage.tsdb.retention.time=7d`. Set the query time range to 2026-09-30 04:52 to 06:12 UTC (10:22 to 11:42 IST).

Note: the file was committed to this branch once (in `aed72bb`) before it was moved to the release, so it remains in the branch history.
