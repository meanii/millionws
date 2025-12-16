locals {
  cluster_name = "millionws"
  environment  = "benchmarking"
  region       = "ap-south-1"
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Key"
  sensitive   = true
}

variable "aws_access_key" {
  type        = string
  description = "AWS Access Key"
  sensitive   = true
}

provider "aws" {
  region     = local.region
  secret_key = var.aws_secret_key
  access_key = var.aws_access_key
}

module "aws_eks" {
  source = "../../modules/aws-eks"

  cluster_name = local.cluster_name
  environment  = local.environment

  enable_cluster_autoscaler = true
  enable_aws_lbc            = true

  nodes = {
    "millionws" = {
      node_group_name = "millionws"
      capacity_type   = "ON_DEMAND" # SPOT, ON_DEMAND
      instance_types  = ["c6a.xlarge"]
      min_size        = 1
      max_size        = 10
      desired_size    = 1
      disk_size       = 20
      tags = {
        Name        = "millionws"
        Environment = "benchmarking"
        Namespace   = "benchmarking"
        Version     = "1.34"
      }
      labels = {
        Name        = "millionws"
        Environment = "benchmarking"
        Namespace   = "benchmarking"
        Version     = "1.34"
      }
    }
    "monitoring" = {
      node_group_name = "monitoring"
      capacity_type   = "ON_DEMAND"
      instance_types  = ["c6a.xlarge"]
      min_size        = 1
      max_size        = 10
      desired_size    = 1
      disk_size       = 20
      tags = {
        Environment = "benchmarking"
        Namespace   = "benchmarking"
        Version     = "1.34"
      }
      labels = {
        role        = "monitoring"
        Environment = "benchmarking"
        Namespace   = "benchmarking"
        Version     = "1.34"
      }
    }
  }
}

# Helm provider
provider "helm" {
  kubernetes = {
    host                   = module.aws_eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.aws_eks.cluster_ca_certificate)
    token                  = module.aws_eks.cluster_auth_token
  }
}

module "helm_deployments" {
  source = "../../modules/helm"
  helm_deployments = {
    metrics-server = {
      enabled          = true
      name             = "metrics-server"
      repository       = "https://kubernetes-sigs.github.io/metrics-server/"
      chart            = "metrics-server"
      namespace        = "kube-system"
      create_namespace = true
      version          = "3.13.0"
      values           = [file("${path.module}/values/metrics-server.yaml")]
    },
    prometheus = {
      enabled          = true
      name             = "prometheus"
      repository       = "https://prometheus-community.github.io/helm-charts"
      chart            = "prometheus"
      namespace        = "monitoring"
      create_namespace = true
      version          = "27.50.1"
      values           = [file("${path.module}/values/prometheus.yaml")]
    },
    grafana = {
      enabled          = true
      name             = "grafana"
      repository       = "https://grafana.github.io/helm-charts"
      chart            = "grafana"
      namespace        = "monitoring"
      create_namespace = true
      version          = "10.3.1"
      values           = [file("${path.module}/values/grafana.yaml")]
    },
  }
  depends_on = [
    module.aws_eks.node_groups
  ]
}

output "update_kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${local.region} --name ${local.cluster_name}"
}
