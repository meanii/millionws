#!/usr/bin/env bash
# Server cloud-init (Amazon Linux 2023): Docker, kernel/file tuning for 1M+
# connections, repo clone, Prometheus targets for every client (discovered
# through the EC2 API, so no Terraform cross-references), compose up.
# Template vars: server_ports ("8080-8095"), expect_clients, replicas, repo_url, git_ref.
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
# 1M connections need ~1 fd each, plus runtime headroom.
fs.file-max = 3000000
fs.nr_open = 2000000
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 16384
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
# Security groups are stateful: every connection takes a conntrack entry.
net.netfilter.nf_conntrack_max = 1048576
SYSCTL
sysctl --system
cat >/etc/security/limits.d/99-millionws.conf <<'LIMITS'
* soft nofile 2000000
* hard nofile 2000000
LIMITS

echo "[cloud-init] cloning repository"
git clone ${repo_url} /home/ec2-user/millionws
git -C /home/ec2-user/millionws checkout ${git_ref}
git -C /home/ec2-user/millionws rev-parse HEAD | tee /home/ec2-user/GIT_SHA
cd /home/ec2-user/millionws/deploy/aws

echo "[cloud-init] waiting for ${expect_clients} clients via EC2 API"
TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
REGION=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')
CLIENT_IPS=""
deadline=$(($(date +%s) + 1200))
while [ "$(date +%s)" -lt "$deadline" ]; do
  CLIENT_IPS=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Name,Values=millionws-client-*" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].PrivateIpAddress" --output text)
  [ "$(echo "$CLIENT_IPS" | wc -w)" -ge "${expect_clients}" ] && break
  echo "[cloud-init] seen so far: $CLIENT_IPS"
  sleep 15
done
echo "[cloud-init] clients: $CLIENT_IPS"

echo "[cloud-init] writing Prometheus targets"
{
  echo "global:"
  echo "  scrape_interval: 5s"
  echo "  scrape_timeout: 4s"
  echo "scrape_configs:"
  echo "  - job_name: server"
  echo "    static_configs:"
  echo "      - targets: [\"server:8080\"]"
  echo "        labels:"
  echo "          namespace: millionws"
  echo "  - job_name: loadgen"
  echo "    static_configs:"
  for ip in $CLIENT_IPS; do
    for r in $(seq 1 ${replicas}); do
      echo "      - targets: [\"$ip:910$r\"]"
    done
  done
} >prometheus.yml

echo "[cloud-init] starting compose stack"
SERVER_PORTS="${server_ports}" docker compose up -d --build
echo "[cloud-init] done"
