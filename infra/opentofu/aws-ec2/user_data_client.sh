#!/usr/bin/env bash
# Client cloud-init (Amazon Linux 2023): Docker, fd tuning, repo clone, build
# the loadgen image once, then run one container per replica. The server is
# discovered through the EC2 API, so no Terraform cross-references.
# Replicas share the client IP (16 server ports x 64k ephemeral ports each
# is plenty), but each exposes its own host metrics port 9101..910N.
# Template vars: port_first, port_count, conns (per replica), replicas, repo_url, git_ref.
LOG=/tmp/cloud-init.log
exec > >(tee -a $LOG) 2>&1

dnf install -y docker git awscli
systemctl enable --now docker
usermod -aG docker ec2-user || true

echo "[cloud-init] tuning kernel and file limits"
# nf_conntrack_max only exists once the module is loaded; without this the
# sysctl below is skipped and Docker loads the module later with its default.
modprobe nf_conntrack
echo nf_conntrack >/etc/modules-load.d/nf_conntrack.conf
cat >/etc/sysctl.d/99-millionws.conf <<'SYSCTL'
fs.file-max = 3000000
fs.nr_open = 2000000
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 16384
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.netfilter.nf_conntrack_max = 1048576
SYSCTL
sysctl --system
cat >/etc/security/limits.d/99-millionws.conf <<'LIMITS'
* soft nofile 2000000
* hard nofile 2000000
LIMITS

echo "[cloud-init] waiting for the server via EC2 API"
TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
REGION=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')
SERVER_IP=""
deadline=$(($(date +%s) + 1200))
while [ -z "$SERVER_IP" ] && [ "$(date +%s)" -lt "$deadline" ]; do
  SERVER_IP=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Name,Values=millionws-server" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].PrivateIpAddress" --output text | head -n 1)
  [ -z "$SERVER_IP" ] && sleep 15
done
if [ -z "$SERVER_IP" ]; then
  echo "[cloud-init] ERROR: server not found after 20 min, giving up" >&2
  exit 1
fi
echo "[cloud-init] server: $SERVER_IP"

URLS=""
for p in $(seq ${port_first} $(( ${port_first} + ${port_count} - 1 ))); do
  URLS="$URLS,ws://$SERVER_IP:$p/ws"
done
URLS=$(echo "$URLS" | sed 's/^,//')
echo "[cloud-init] loadgen URLs: $URLS"

echo "[cloud-init] cloning repository and building loadgen"
git clone ${repo_url} /home/ec2-user/millionws
git -C /home/ec2-user/millionws checkout ${git_ref}
git -C /home/ec2-user/millionws rev-parse HEAD | tee /home/ec2-user/GIT_SHA
cd /home/ec2-user/millionws
docker build -q --target loadgen -t millionws:loadgen . >/dev/null

echo "[cloud-init] starting ${replicas} loadgen replicas, ${conns} conns each"
for i in $(seq 1 ${replicas}); do
  port=$((9100 + i))
  docker run -d --restart unless-stopped --name "loadgen-$i" \
    --ulimit "nofile=1048576:1048576" \
    --sysctl net.ipv4.ip_local_port_range="1024 65535" \
    -p "$port:9100" \
    -e LOADGEN_URL="$URLS" \
    -e LOADGEN_CONNS="${conns}" \
    millionws:loadgen
done
echo "[cloud-init] done"
