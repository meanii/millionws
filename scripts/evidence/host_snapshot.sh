#!/usr/bin/env bash
# Prints a labelled snapshot of one instance. Run it over SSH, for example:
#   ssh ec2-user@<host> 'bash -s' < scripts/evidence/host_snapshot.sh > server_snapshot.txt
sec() { echo; echo "### $1"; }
sec "date (utc and local)"; date -u +%FT%TZ; date +%FT%T%z; timedatectl 2>/dev/null | grep -E 'Time zone'
sec "uname"; uname -a
sec "git sha"; cat ~/GIT_SHA 2>/dev/null
sec "instance type, az"; T=$(curl -sX PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60"); curl -sH "X-aws-ec2-metadata-token: $T" http://169.254.169.254/latest/meta-data/instance-type; echo; curl -sH "X-aws-ec2-metadata-token: $T" http://169.254.169.254/latest/meta-data/placement/availability-zone; echo
sec "free -m"; free -m
sec "meminfo (selected)"; grep -E 'MemTotal|MemAvailable|^Slab|SReclaimable|SUnreclaim|Cached|AnonPages' /proc/meminfo
sec "sockstat"; cat /proc/net/sockstat
sec "ss -s"; ss -s
sec "ss -tin sample (first 12 established, with TCP internals)"; ss -tin state established 2>/dev/null | head -25
sec "sysctl"; sysctl fs.nr_open fs.file-max net.core.somaxconn net.ipv4.ip_local_port_range net.ipv4.tcp_max_syn_backlog 2>/dev/null
sec "docker ps"; sudo docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
sec "docker stats"; sudo docker stats --no-stream --format '{{.Name}}\tcpu={{.CPUPerc}}\tmem={{.MemUsage}}'
sec "ENA"; IF=$(ip -o -4 route show to default | awk '{print $5}'); echo "iface=$IF"; sudo ethtool -S "$IF" 2>/dev/null | grep -E 'allowance|conntrack'
sec "server container cgroup"; C=$(sudo docker inspect -f '{{.Id}}' aws-server-1 2>/dev/null)
if [ -n "$C" ]; then D=/sys/fs/cgroup/system.slice/docker-$C.scope; for f in memory.current memory.max; do echo -n "$f="; sudo cat "$D/$f"; done; sudo grep -E '^(anon|file|kernel|kernel_stack|slab|sock|slab_reclaimable|slab_unreclaimable) ' "$D/memory.stat"; fi
sec "server log, lines that are not INF"; sudo docker logs aws-server-1 2>&1 | grep -vE ' \[INF\] ' | cut -c1-260 | tail -8
sec "sampler csv (last 3 rows)"; tail -n 3 ~/evidence/samples.csv 2>/dev/null
