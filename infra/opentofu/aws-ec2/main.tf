# MillionWS load-test stack on plain EC2 (no EKS, no load balancer).
#
# Usage:
#   terraform init
#   terraform apply \
#     -var my_ip=<your-public-ip>/32 \
#     -var key_name=<existing-ec2-key-pair> \
#     -var git_ref=<branch, tag or commit SHA to build>
#   # ... run the benchmark, watch Grafana ...
#   terraform destroy   # every session ends here; idle setup costs ~$800/mo
#
# Design (see docs/roadmap.md): one AZ, private-IP traffic (no NAT, no data
# charges), 1 server × 16 ports, N clients. 4 clients × 16 ports × 64k
# ephemeral ports each ≈ 4M capacity for the 1M target.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "one" {
  state = "available"
}

locals {
  az = data.aws_availability_zones.one.names[0]
}

# ---------------------------------------------------------------- VPC ---

resource "aws_vpc" "bench" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "millionws-bench" }
}

resource "aws_internet_gateway" "bench" {
  vpc_id = aws_vpc.bench.id
  tags   = { Name = "millionws-bench" }
}

resource "aws_subnet" "bench" {
  vpc_id                  = aws_vpc.bench.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = true
  tags                    = { Name = "millionws-bench" }
}

resource "aws_route_table" "bench" {
  vpc_id = aws_vpc.bench.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bench.id
  }
  tags = { Name = "millionws-bench" }
}

resource "aws_route_table_association" "bench" {
  subnet_id      = aws_subnet.bench.id
  route_table_id = aws_route_table.bench.id
}

# ----------------------------------------------- security group ---

resource "aws_security_group" "bench" {
  name   = "millionws-bench"
  vpc_id = aws_vpc.bench.id

  # SSH and dashboards only from the operator.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  # Everything between the instances: server ports, loadgen metrics,
  # Prometheus scrapes.
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "millionws-bench" }
}

# ---------------------------------------------------------- IAM ---
# Both sides discover each other through the EC2 API (instances tagged
# below), so neither user_data needs the other's address at plan time.

resource "aws_iam_role" "bench" {
  name = "millionws-bench-discover"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "bench" {
  name = "millionws-bench-discover"
  role = aws_iam_role.bench.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "ec2:DescribeInstances"
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "bench" {
  name = "millionws-bench-discover"
  role = aws_iam_role.bench.name
}

# ------------------------------------------------------- AMI ---

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ------------------------------------------------ server + clients ---
# Spot is requested through instance_market_options on aws_instance, not
# aws_spot_instance_request: the latter tags only the request, so the
# launched instance would have no Name tag and the EC2-API discovery in
# cloud-init would never find its peers.

locals {
  market = var.use_spot ? [1] : []
}

resource "aws_instance" "server" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.server_type
  subnet_id                   = aws_subnet.bench.id
  vpc_security_group_ids      = [aws_security_group.bench.id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.bench.name
  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/user_data_server.sh", {
    server_ports   = "${var.server_port_first}-${var.server_port_first + var.server_port_count - 1}"
    expect_clients = var.client_count
    replicas       = var.client_replicas
    repo_url       = var.repo_url
    git_ref        = var.git_ref
  })
  dynamic "instance_market_options" {
    for_each = local.market
    content {
      market_type = "spot"
      spot_options {
        # one-time: a persistent request would relaunch a replacement
        # after an interruption and keep billing.
        spot_instance_type             = "one-time"
        instance_interruption_behavior = "terminate"
      }
    }
  }
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }
  tags = { Name = "millionws-server" }
}

resource "aws_instance" "client" {
  count                       = var.client_count
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.client_type
  subnet_id                   = aws_subnet.bench.id
  vpc_security_group_ids      = [aws_security_group.bench.id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.bench.name
  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/user_data_client.sh", {
    port_first = var.server_port_first
    port_count = var.server_port_count
    # floor: the loadgen rejects a fractional LOADGEN_CONNS.
    conns    = floor(var.conns_per_client / var.client_replicas)
    replicas = var.client_replicas
    repo_url = var.repo_url
    git_ref  = var.git_ref
  })
  dynamic "instance_market_options" {
    for_each = local.market
    content {
      market_type = "spot"
      spot_options {
        spot_instance_type             = "one-time"
        instance_interruption_behavior = "terminate"
      }
    }
  }
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }
  tags = { Name = "millionws-client-${count.index}" }
}

locals {
  server_public_ip  = aws_instance.server.public_ip
  client_public_ips = aws_instance.client[*].public_ip
}
