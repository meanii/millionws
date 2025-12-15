locals {
  cluster_name = "locust"
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

  enable_cluster_autoscaler = true
  enable_aws_lbc            = true

  nodes = {
    "locust" = {
      node_group_name = "locust"
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
    locust-operator = {
      enabled          = true
      name             = "locust-operator"
      repository       = "https://locustcloud.github.io/k8s-operator"
      chart            = "locust-operator"
      namespace        = "locust"
      create_namespace = true
      version          = "0.1.8"
      values           = [file("${path.module}/values/locust-operator.yaml")]
    },
  }
}

output "update_kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${local.region} --name ${local.cluster_name}"
}
