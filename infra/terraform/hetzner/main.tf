#
# # list of servers
# ➜  ~ export HZ_TOKEN="xxxxxxxxx"
# ➜  ~ curl -s -H "Authorization: Bearer $HZ_TOKEN" "https://api.hetzner.cloud/v1/server_types" | jq '.server_types[].name'
# "cpx11"
# "cpx21"..
#
# # list of images
# curl -s -H "Authorization: Bearer $HZ_TOKEN" "https://api.hetzner.cloud/v1/images" | jq '.images[].name'
# "ubuntu-20.04"
# "ubuntu-22.04"
# "alma-8"
# "alma-9"
#
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.59.0"
    }
  }
}


# Set the variable value in *.tfvars file
# or using the -var="hcloud_token=..." CLI option
variable "hcloud_token" {
  sensitive = true
}

# Configure the Hetzner Cloud Provider
provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_ssh_key" "main" {
  name       = "pop_os_default_ssh"
  public_key = file("~/.ssh/id_ed25519.pub")
}

# Create a new server running debian
# use `cx23` for testing purpose deployment because of €0.005 / h
# or alt `cx33` €0.008 / h 4.99 / mo
# `ccx33` for actual workload, 8 AMD vCPU, 32 RAM - €0.077 / h
resource "hcloud_server" "millionws" {
  name     = "millionws-hz"
  image    = "ubuntu-24.04"
  location = "nbg1" # https://docs.hetzner.com/cloud/general/locations/#what-locations-are-there
  labels = {
    "benchmarking" : "true"
    "millionws" : "true"
  }
  ssh_keys = [
    hcloud_ssh_key.main.name
  ]
  server_type = "cx23"
  public_net {
    ipv4_enabled = true  # €0.50 /mo
    ipv6_enabled = false # free basically, do not use it - you might end up having compatible issues from your any device end
  }
  user_data = <<EOF
#!/usr/bin/env bash

LOG=/tmp/cloud-init.log

echo "[cloud-init] starting cloud-init script" >> $LOG

# Ensure non-interactive apt
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y \
  ca-certificates \
  curl \
  git

echo "[cloud-init] installed base packages" >> $LOG

echo "[cloud-init] installing docker"
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker

# Allow ubuntu/root to run docker without sudo (optional)
usermod -aG docker ubuntu || true

echo "[cloud-init] tuning kernel parameters" >> $LOG
cat >/etc/sysctl.d/99-millionws.conf <<'SYSCTL'
fs.file-max = 1000000
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 16384
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
SYSCTL

sysctl --system

echo "[cloud-init] raising file descriptor limits" >> $LOG
cat >/etc/security/limits.d/99-millionws.conf <<'LIMITS'
* soft nofile 200000
* hard nofile 200000
root soft nofile 200000
root hard nofile 200000
LIMITS

# Ensure home exists (cloud-init runs as root)
mkdir -p /root/millionws

echo "[cloud-init] cloning repository" >> $LOG
git clone https://github.com/meanii/millionws.git /root/millionws

echo "[cloud-init] starting docker compose" >> $LOG
cd /root/millionws/deploy/hetzner
docker compose up -d

echo "[cloud-init] cloud-init done" >> $LOG
EOF

}

output "server" {
  value = "server has been created\nssh root@${hcloud_server.millionws.ipv4_address}"
}

output "grafana" {
  value = "\ngrafana http://${hcloud_server.millionws.ipv4_address}:8001\nusername: admin\npassword: admin"
}

output "prometheus" {
  value = "\nprometheus http://${hcloud_server.millionws.ipv4_address}:9090\n"
}
