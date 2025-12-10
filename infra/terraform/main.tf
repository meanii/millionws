provider "aws" {
  region = "ap-south-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.25.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
  }
}

locals {
  env         = "test"
  name        = "locust"
  eks_name    = "locust"
  eks_version = "1.34"
  region      = "ap-south1"
  zone1       = "ap-south-1a"
  zone2       = "ap-south-1b"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name}-main"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name}-igw"
  }
}

resource "aws_subnet" "private_zone_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/19"
  availability_zone = local.zone1

  tags = {
    Name                                               = "${local.name}-private-${local.zone1}"
    "kubernetes.io/role/internal-elb"                  = "1"     # docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html
    "kubernetes.io/cluster/${local.env}-${local.name}" = "owned" # owned or shared, this for managing multiple clusters in single aws account
  }
}

resource "aws_subnet" "private_zone_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.32.0/19"
  availability_zone = local.zone2

  tags = {
    Name                                               = "${local.name}-private-${local.zone2}"
    "kubernetes.io/role/internal-elb"                  = "1"     # docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html
    "kubernetes.io/cluster/${local.env}-${local.name}" = "owned" # owned or shared, this for managing multiple clusters in single aws account
  }
}

resource "aws_subnet" "public_zone_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.64.0/19"
  availability_zone       = local.zone1
  map_public_ip_on_launch = true

  tags = {
    Name                                               = "${local.name}-public-${local.zone1}"
    "kubernetes.io/role/elb"                           = "1"     # docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html
    "kubernetes.io/cluster/${local.env}-${local.name}" = "owned" # owned or shared, this for managing multiple clusters in single aws account
  }
}


resource "aws_subnet" "public_zone_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.96.0/19"
  availability_zone       = local.zone2
  map_public_ip_on_launch = true

  tags = {
    Name                                               = "${local.name}-public-${local.zone2}"
    "kubernetes.io/role/elb"                           = "1"     # docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html
    "kubernetes.io/cluster/${local.env}-${local.name}" = "owned" # owned or shared, this for managing multiple clusters in single aws account
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "${local.name}-nat"
  }
}


resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_zone_1.id

  tags = {
    Name = "${local.name}-nat"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}


resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${local.name}-private"
  }
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${local.name}-public"
  }
}

resource "aws_route_table_association" "private_zone_1" {
  subnet_id      = aws_subnet.private_zone_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_zone_2" {
  subnet_id      = aws_subnet.private_zone_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public_zone_1" {
  subnet_id      = aws_subnet.public_zone_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_zone_2" {
  subnet_id      = aws_subnet.public_zone_2.id
  route_table_id = aws_route_table.public.id
}


# EKS configs
resource "aws_iam_role" "eks" {
  name = "${local.env}-${local.name}-eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "eks.amazonaws.com"
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_eks_cluster" "eks" {
  name     = "${local.env}-${local.name}"
  version  = local.eks_version
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    endpoint_private_access = false
    endpoint_public_access  = true

    subnet_ids = [
      aws_subnet.private_zone_1.id,
      aws_subnet.private_zone_2.id
    ]
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks]

}


# EKS Node Group
resource "aws_iam_role" "nodes" {
  name = "${local.env}-${local.name}-eks-nodes"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
POLICY
}

# This policy now includes AssumeRoleForPodIdentity for the Pod Identity Agent
resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.eks.name
  version         = local.eks_version
  node_group_name = "general"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids = [
    aws_subnet.private_zone_1.id,
    aws_subnet.private_zone_2.id,
  ]
  capacity_type  = "SPOT" # either SPOT or ON_DEMAND
  instance_types = ["t3.large"]
  disk_size      = 50

  scaling_config {
    desired_size = 1
    max_size     = 10
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "general"
  }

  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only,
  ]

  # Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

}

output "update_kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ap-south-1 --name ${aws_eks_cluster.eks.name}"
}

# Helm provider
data "aws_eks_cluster" "eks" {
  name = aws_eks_cluster.eks.name
}

data "aws_eks_cluster_auth" "eks" {
  name = aws_eks_cluster.eks.name
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

# https://artifacthub.io/packages/helm/metrics-server/metrics-server
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.13.0"

  values = [file("${path.module}/values/metrics-server.yaml")]

  depends_on = [aws_eks_node_group.general]
}

# https://docs.locust.io/en/stable/locust-cloud/kubernetes-operator.html#inline-locustfile
resource "helm_release" "locust-operator" {
  name             = "locust-operator"
  repository       = "https://locustcloud.github.io/k8s-operator"
  chart            = "locust-operator"
  namespace        = "locust"
  create_namespace = true
  version          = "0.1.8"

  values = [file("${path.module}/values/locust.yaml")]

  depends_on = [aws_eks_node_group.general]
}
