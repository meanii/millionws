locals {
  cluster_name = "millionws"
  environment  = "benchmarking"
  region       = "ap-south-1"
}

provider "aws" {
  region = local.region
}

module "aws_eks" {
  source = "../../modules/aws-eks"

  cluster_name = local.cluster_name
  environment  = local.environment

  nodes = {
    "millionws" = {
      node_group_name = "millionws"
      capacity_type   = "SPOT"
      instance_type   = "t3.small"
      min_size        = 1
      max_size        = 10
      desired_size    = 1
      disk_size       = 20
      tags = {
        Name        = "locust-nodes"
        Environment = "benchmarking"
        Namespace   = "benchmarking"
        Version     = "1.34"
      }
      labels = {
        Name        = "locust-nodes"
        Environment = "benchmarking"
        Namespace   = "benchmarking"
        Version     = "1.34"
      }
    }
    "monitoring" = {
      node_group_name = "monitoring"
      capacity_type   = "SPOT"
      instance_type   = "t3.small"
      min_size        = 1
      max_size        = 10
      desired_size    = 1
      disk_size       = 20
      tags = {
        Name        = "monitor-nodes"
        Environment = "benchmarking"
        Namespace   = "benchmarking"
        Version     = "1.34"
      }
      labels = {
        Name        = "monitor-nodes"
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
  }
}

output "update_kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${local.region} --name ${local.cluster_name}"
}
