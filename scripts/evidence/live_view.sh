#!/usr/bin/env bash
# A compact live view of the server, meant to be recorded with asciinema:
#   asciinema rec -c "ssh -tt ec2-user@<server> 'bash -s' < live_view.sh" run.cast
# (or copy it over and run it there). Prints one refreshed screen every 2 s in
# the machine's own timezone, and exits after DURATION seconds (default 600).
DURATION=${1:-600}
end=$((SECONDS + DURATION))
IF=$(ip -o -4 route show to default | awk '{print $5}')
while [ $SECONDS -lt $end ]; do
  clear
  echo "millionws live view  $(date '+%F %T %Z')   host $(hostname -s)   $(uname -r)"
  echo "----------------------------------------------------------------------------"
  m=$(curl -s -m2 localhost:8080/metrics 2>/dev/null)
  active=$(echo "$m" | awk '/^millionws_connections_active/ {printf "%d", $2}')
  rej=$(echo "$m" | awk '/^millionws_connections_rejected_total/ {printf "%d", $2}')
  uerr=$(echo "$m" | awk '/^millionws_upgrade_errors_total/ {printf "%d", $2}')
  fds=$(echo "$m" | awk '/^process_open_fds/ {printf "%d", $2}')
  rss=$(echo "$m" | awk '/^process_resident_memory_bytes/ {printf "%d", $2/1048576}')
  gor=$(echo "$m" | awk '/^go_goroutines/ {printf "%d", $2}')
  printf "server: connections_active %-9s rejected %-4s upgrade_errors %-4s\n" "${active:-n/a (busy)}" "${rej:-?}" "${uerr:-?}"
  printf "        open_fds %-9s goroutines %-4s process RSS %s MiB\n" "${fds:-?}" "${gor:-?}" "${rss:-?}"
  echo "kernel: $(ss -s | awk '/^TCP:/')"
  echo "memory: $(free -m | awk '/^Mem:/ {printf "used %d MiB, available %d MiB of %d MiB", $3, $7, $2}')"
  echo "cpu   : load $(cut -d' ' -f1-3 /proc/loadavg)   $(top -bn1 | awk '/^%Cpu/ {print "busy " 100-$8 "%"}')"
  echo "ENA   : $(sudo ethtool -S "$IF" 2>/dev/null | awk '/conntrack_allowance_exceeded/ {ce=$2} /conntrack_allowance_available/ {ca=$2} /pps_allowance_exceeded/ {pp=$2} END {printf "conntrack_exceeded=%s conntrack_available=%s pps_exceeded=%s", ce, ca, pp}')"
  echo "----------------------------------------------------------------------------"
  sudo docker stats --no-stream --format 'container {{.Name}}  cpu {{.CPUPerc}}  mem {{.MemUsage}}' 2>/dev/null
  sleep 2
done
