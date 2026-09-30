#!/usr/bin/env bash
# 1 Hz log of the server container's memory breakdown and established sockets.
# Usage: memwatch.sh [seconds] [container]   (run on the instance, prints CSV)
DUR=${1:-120}; C=${2:-aws-server-1}
cid=$(docker inspect -f '{{.Id}}' "$C") || exit 1
D=/sys/fs/cgroup/system.slice/docker-$cid.scope
echo "local,current_mib,anon_mib,kernel_mib,sock_mib,slab_mib,estab"
end=$((SECONDS + DUR))
while [ $SECONDS -lt $end ]; do
  s=$(awk '/^anon /{a=$2} /^kernel /{k=$2} /^sock /{s=$2} /^slab /{sl=$2} END {printf "%d,%d,%d,%d", a/1048576, k/1048576, s/1048576, sl/1048576}' "$D/memory.stat")
  echo "$(date +%T),$(($(cat $D/memory.current) / 1048576)),$s,$(awk '/^TCP:/ {for (i=1;i<=NF;i++) if ($i=="(estab") {gsub(",","",$(i+1)); print $(i+1)}}' < <(ss -s))"
  sleep 1
done
