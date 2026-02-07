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
resource "hcloud_server" "server" {
  name     = "millionws-hz"
  image    = "ubuntu-24.04"
  location = "fsn1" # https://docs.hetzner.com/cloud/general/locations/#what-locations-are-there
  labels = {
    "benchmarking" : "true"
    "millionws" : "true"
  }
  ssh_keys = [
    hcloud_ssh_key.main.name
  ]
  server_type = "cx33"
  public_net {
    ipv4_enabled = true  # €0.50 /mo
    ipv6_enabled = false # free basically, do not use it - you might end up having compatible issues from your any device end
  }
  user_data = <<EOF
#!/bin/bash
echo "[cloud-init] starting cloud-init script" >> /tmp/cloud-init.log

apt-get update -y
apt-apt install curl -y
echo "[cloud-init] updated and installed packages" >> /tmp/cloud-init.log

echo "[cloud-init] installing docker & docker compose" >> /tmp/cloud-init.log
curl -o- https://get.docker.com | sh
systemctl enable --now docker

echo "[cloud-init] started docker daemon" >> /tmp/cloud-init.log
git clone https://github.com/meanii/millionws.git ~/millionws

echo "[cloud-init] starting compose.yaml for locust" >> /tmp/cloud-init.log
docker compose -f ~/millionws/deploy/hetzner/compose.yml up -d
echo "[cloud-init] cloud-init done" >> /tmp/cloud-init.log
EOF
}

output "server" {
  value = "server has been created\nssh root@${hcloud_server.server.ipv4_address}"
}

output "grafana" {
  value = "grafana http://${hcloud_server.server.ipv4_address}:8001\nusername: admin\npassword: admin"
}

output "prometheus" {
  value = "prometheus http://${hcloud_server.server.ipv4_address}:9090"
}
