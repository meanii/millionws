#!/usr/bin/env bash
# Run one local benchmark: start the capped server, record idle usage, start the
# load generators, and record until the server stops accepting connections, the
# target is held, or the time limit passes.
#
# Usage: bench/local/run.sh <variant> [total_connections] [loadgen_replicas]
#
# <variant> is a file in bench/local/variants/. Results go to
# results/local/<date>-<variant>/.
#
# Environment overrides:
#   SERVER_CPUS (1)  SERVER_MEM (1g)  LOADGEN_RATE (1000/replicas per replica)
#   LOADGEN_INTERVAL (30s)  HOLD (60)  PLATEAU (90)  MAX (1800)  KEEP (0)
set -euo pipefail

variant=${1:?usage: run.sh <variant> [total_connections] [loadgen_replicas]}
total=${2:-200000}
replicas=${3:-4}

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
cd "$here"

set -a
# shellcheck source=/dev/null
source "variants/$variant.env"
SERVER_IMAGE=millionws-bench:$variant
LOADGEN_CONNS=$(( (total + replicas - 1) / replicas ))
SERVER_CPUS=${SERVER_CPUS:-1}
SERVER_MEM=${SERVER_MEM:-1g}
LOADGEN_RATE=${LOADGEN_RATE:-$(( 1000 / replicas ))} # 1,000 new connections per second in total
set +a

out="$root/results/local/$(date +%F)-$variant"
n=2
while [[ -e $out ]]; do out="$root/results/local/$(date +%F)-$variant-$n"; n=$((n + 1)); done
mkdir -p "$out"

echo "==> building server image from ${SERVER_REF}"
if [[ $SERVER_REF == worktree ]]; then
  docker build -q --target server -t "$SERVER_IMAGE" "$root" >/dev/null
  server_sha="$(git -C "$root" rev-parse --short HEAD) plus uncommitted changes: $(git -C "$root" status --porcelain | wc -l) files"
else
  git -C "$root" archive "$SERVER_REF" | docker build -q -t "$SERVER_IMAGE" - >/dev/null
  server_sha=$(git -C "$root" rev-parse --short "$SERVER_REF")
fi
docker compose build -q loadgen

cat >"$out/environment.md" <<EOF
# Environment

| Item | Value |
| --- | --- |
| Date | $(date -u +"%F %H:%M UTC") |
| Variant | \`$variant\` |
| Server code | \`$server_sha\` |
| Harness commit | \`$(git -C "$root" rev-parse --short HEAD)\` |
| Server limits | ${SERVER_CPUS} CPU, ${SERVER_MEM} memory, no swap, nofile 1048576 |
| Server tuning | GOMEMLIMIT=\`${SERVER_GOMEMLIMIT:-unset}\`, GOGC=\`${SERVER_GOGC:-unset}\` |
| Load generators | ${replicas} containers x ${LOADGEN_CONNS} connections, ${LOADGEN_RATE} dials/s each |
| Messages | ${LOADGEN_PAYLOAD:-32} bytes every ${LOADGEN_INTERVAL:-30s} per connection |
| Host CPU | $(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs), $(nproc) threads |
| Host memory | $(free -g | awk '/Mem:/ {print $2}') GiB |
| Kernel | $(uname -r) |
| Docker | $(docker version --format '{{.Server.Version}}') |
| Docker mode | $(docker info --format '{{range .SecurityOptions}}{{.}} {{end}}' | grep -q rootless && echo rootless || echo rootful) |
EOF

echo "==> starting server and prometheus"
docker compose down -v --remove-orphans >/dev/null 2>&1 || true
docker compose up -d server prometheus netwatch >/dev/null 2>&1
echo "| Docker network nf_conntrack_max | $(docker exec millionws-bench-netwatch-1 cat /proc/sys/net/netfilter/nf_conntrack_max) |" >>"$out/environment.md"
for _ in $(seq 60); do
  curl -sf http://127.0.0.1:18080/health >/dev/null && break
  sleep 1
done
sleep 12 # let Prometheus scrape the idle server at least twice

cid=$(docker compose ps -q server)
cid=$(docker inspect -f '{{.Id}}' "$cid")
python3 record.py idle --container "$cid" --out "$out"

echo "==> starting $replicas load generators, $LOADGEN_CONNS connections each"
docker compose up -d --no-recreate --scale loadgen="$replicas" loadgen >/dev/null 2>&1

python3 record.py run --container "$cid" --out "$out" --variant "$variant" \
  --hold "${HOLD:-60}" --plateau "${PLATEAU:-90}" --max "${MAX:-1800}" || true

docker logs --tail 200 "$cid" >"$out/server.log" 2>&1 || true
docker compose logs --no-color --tail 20 loadgen >"$out/loadgen.log" 2>&1 || true

if [[ ${KEEP:-0} == 1 ]]; then
  echo "==> stack left running (KEEP=1); stop it with: docker compose -f $here/compose.yaml down -v"
else
  docker compose down -v >/dev/null 2>&1
fi
echo "==> results in ${out#"$root"/}"
