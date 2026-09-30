#!/usr/bin/env bash
# Freezes the server process for N seconds (SIGSTOP, then SIGCONT) to model a
# stalled read path: clients keep sending, the kernel keeps accepting into
# socket buffers charged to the container, nothing is read or echoed.
# Run on the server instance. Usage: stall.sh <seconds>
set -u
S=${1:?usage: stall.sh <seconds>}
PID=$(pgrep -x millionws | head -1)
[ -n "$PID" ] || { echo "no millionws process"; exit 1; }
echo "$(date +%T.%N | cut -c1-12) STOP pid $PID for ${S}s"
sudo kill -STOP "$PID"
sleep "$S"
if sudo kill -CONT "$PID" 2>/dev/null; then echo "$(date +%T.%N | cut -c1-12) CONT"; else echo "$(date +%T.%N | cut -c1-12) CONT failed: process is gone (killed while stopped)"; fi
