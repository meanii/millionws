#!/usr/bin/env bash
# Starts one more loadgen container on a client, with the same targets as
# loadgen-1, so a run can be scaled up without dropping existing connections.
# Its metrics listen on loopback (Prometheus does not scrape it; the server's
# own connection count includes it). Run on a client instance.
# Usage: add_loadgen.sh <container-name> <loopback-metrics-port> <connections> [dials-per-second]
set -eu
NAME=${1:?name}; PORT=${2:?port}; CONNS=${3:?connections}; RATE=${4:-1000}
URLS=$(sudo docker inspect loadgen-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep '^LOADGEN_URL=' | cut -d= -f2-)
sudo docker run -d --restart unless-stopped --name "$NAME" --network host \
  --ulimit nofile=1048576:1048576 -e TZ="$(cat /etc/timezone 2>/dev/null || echo UTC)" \
  -e LOADGEN_METRICS="127.0.0.1:$PORT" -e LOADGEN_URL="$URLS" \
  -e LOADGEN_CONNS="$CONNS" -e LOADGEN_RATE="$RATE" millionws:loadgen >/dev/null
echo "$NAME started: $CONNS connections at $RATE dials/s"
