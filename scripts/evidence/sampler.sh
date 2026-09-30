#!/usr/bin/env bash
# Runs on an instance from boot and appends one CSV row every INTERVAL seconds:
# established TCP sockets, CPU, memory, kernel slab, TCP memory, the container's
# cgroup memory and the ENA allowance counters. It keeps recording even if SSH
# to the instance is flaky, so a run always has a time series.
# Usage: sampler.sh [out.csv] [interval_seconds] [container_name]
OUT=${1:-$HOME/evidence/samples.csv}
INTERVAL=${2:-10}
CONTAINER=${3:-aws-server-1}
mkdir -p "$(dirname "$OUT")"
IF=$(ip -o -4 route show to default | awk '{print $5}')
echo "utc,local,estab,load1,cpu_pct,mem_used_mib,slab_mib,tcp_mem_pages,container_mem_mib,ena_conntrack_exceeded,ena_conntrack_available,ena_pps_exceeded,ena_bw_in_exceeded,ena_bw_out_exceeded" >"$OUT"
read -r _ u n s idle rest </proc/stat
prev_total=$((u + n + s + idle)); prev_idle=$idle
while true; do
  utc=$(date -u +%FT%TZ); local_=$(date +%FT%T%z)
  estab=$(ss -s | awk '/^TCP:/ {for (i = 1; i <= NF; i++) if ($i == "(estab") {gsub(",", "", $(i + 1)); print $(i + 1)}}')
  load1=$(cut -d' ' -f1 /proc/loadavg)
  read -r _ u n s idle rest </proc/stat
  total=$((u + n + s + idle)); dt=$((total - prev_total)); di=$((idle - prev_idle))
  cpu=$(awk -v dt="$dt" -v di="$di" 'BEGIN { if (dt > 0) printf "%.1f", 100 * (dt - di) / dt }')
  prev_total=$total; prev_idle=$idle
  mem=$(awk '/^MemTotal/ {t=$2} /^MemAvailable/ {a=$2} END {printf "%d", (t - a) / 1024}' /proc/meminfo)
  slab=$(awk '/^Slab:/ {printf "%d", $2 / 1024}' /proc/meminfo)
  tcpmem=$(awk '/^TCP:/ {for (i = 1; i <= NF; i++) if ($i == "mem") print $(i + 1)}' /proc/net/sockstat)
  cmem=""
  cid=$(docker inspect -f '{{.Id}}' "$CONTAINER" 2>/dev/null)
  if [ -n "$cid" ] && [ -r "/sys/fs/cgroup/system.slice/docker-$cid.scope/memory.current" ]; then
    cmem=$(($(cat "/sys/fs/cgroup/system.slice/docker-$cid.scope/memory.current") / 1048576))
  fi
  ena=$(ethtool -S "$IF" 2>/dev/null | awk '/conntrack_allowance_exceeded/ {ce=$2} /conntrack_allowance_available/ {ca=$2} /pps_allowance_exceeded/ {pp=$2} /bw_in_allowance_exceeded/ {bi=$2} /bw_out_allowance_exceeded/ {bo=$2} END {print ce "," ca "," pp "," bi "," bo}')
  echo "$utc,$local_,$estab,$load1,$cpu,$mem,$slab,$tcpmem,$cmem,${ena:-,,,,}" >>"$OUT"
  sleep "$INTERVAL"
done
