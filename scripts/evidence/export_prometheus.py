#!/usr/bin/env python3
"""Export the run's Prometheus series as JSON (range queries).
Usage: export_prometheus.py <host> <start RFC3339 or unix> <end> <out.json> [step_s]
"""
import json, sys, urllib.parse, urllib.request

host, start, end, out = sys.argv[1:5]
step = sys.argv[5] if len(sys.argv) > 5 else "10"
Q = {
    "loadgen_connections_active_total": "sum(loadgen_connections_active)",
    "loadgen_connections_active_by_replica": "loadgen_connections_active",
    "server_connections_active": "millionws_connections_active",
    "server_connections_total": "millionws_connections_total",
    "server_connections_rejected_total": "millionws_connections_rejected_total",
    "server_upgrade_errors_total": "millionws_upgrade_errors_total",
    "server_disconnections_total": "millionws_disconnections_total",
    "loadgen_dials_rate_15s": "sum(rate(loadgen_dials_total[15s]))",
    "loadgen_dial_errors_by_reason": "sum(loadgen_dial_errors_total) by (reason)",
    "loadgen_disconnects_total": "sum(loadgen_disconnects_total)",
    "loadgen_messages_sent_rate_15s": "sum(rate(loadgen_messages_sent_total[15s]))",
    "loadgen_messages_received_rate_15s": "sum(rate(loadgen_messages_received_total[15s]))",
    "echo_latency_p50_seconds_30s": "histogram_quantile(0.5, sum(rate(loadgen_echo_latency_seconds_bucket[30s])) by (le))",
    "echo_latency_p99_seconds_30s": "histogram_quantile(0.99, sum(rate(loadgen_echo_latency_seconds_bucket[30s])) by (le))",
    "server_process_resident_memory_bytes": 'process_resident_memory_bytes{job="server"}',
    "server_process_start_time_seconds": 'process_start_time_seconds{job="server"}',
    "server_open_fds": 'process_open_fds{job="server"}',
    "server_goroutines": 'go_goroutines{job="server"}',
    "server_go_memory_limit_bytes": "millionws_go_memory_limit_bytes",
    "server_go_heap_alloc_bytes": 'go_memstats_alloc_bytes{job="server"}',
    "scrape_up": "up",
}
res = {}
for name, q in Q.items():
    url = f"http://{host}:9090/api/v1/query_range?" + urllib.parse.urlencode({"query": q, "start": start, "end": end, "step": step})
    try:
        d = json.load(urllib.request.urlopen(url, timeout=60))
        res[name] = {"query": q, "result": d["data"]["result"]}
        print(f"{name}: {sum(len(r['values']) for r in d['data']['result'])} points, {len(d['data']['result'])} series")
    except Exception as e:
        res[name] = {"query": q, "error": str(e)}
        print(name, "ERROR", e)
json.dump({"start": start, "end": end, "step_s": int(step), "series": res}, open(out, "w"))
