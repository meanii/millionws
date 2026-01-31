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

# Create a new server running debian
# use `cx23` for testing purpose deployment because of €0.005 / h
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
    "hi@meanii.dev" # default ssh key
  ]
  server_type = "cx23"
  public_net {
    ipv4_enabled = true  # €0.50 /mo
    ipv6_enabled = false # free basically, do not use it - you might end up having compatible issues from your any device end
  }
}


output "server" {
  value = "server has been created\nssh root@${hcloud_server.server.ipv4_address}"
}
