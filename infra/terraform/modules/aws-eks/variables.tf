variable "cluster_name" {
  description = "Name of the EKS cluster. Must be unique."
  type        = string
}

variable "eks_version" {
  description = "Name of the EKS cluster. Must be unique."
  type        = string
  default     = "1.34"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "enable_cluster_autoscaler" {
  description = "Enable cluster autoscaler"
  type        = bool
  default     = false
}

variable "enable_aws_lbc" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Name of the environment"
  type        = string
  default     = "benchmarking"
}


variable "nodes" {
  description = "Declare nodes"
  type = map(object({
    node_group_name = string
    capacity_type   = string # SPOT, ON_DEMAND
    instance_type   = string
    min_size        = number
    max_size        = number
    desired_size    = number
    disk_size       = number
    tags            = map(string)
    labels          = map(string)
  }))
  default = {
    "general" = {
      node_group_name = "general"
      capacity_type   = "ON_DEMAND"
      instance_type   = "t3.medium"
      min_size        = 1
      max_size        = 10
      desired_size    = 1
      disk_size       = 20
      tags = {
        "Name"        = "general"
        "Environment" = "benchmarking"
        "Cluster"     = "locust"
        "Terraform"   = "true"
      }
      labels = {
        "app"  = "locust"
        "role" = "general"
      }
    }
    "monitoring" = {
      node_group_name = "monitoring"
      capacity_type   = "SPOT"
      instance_type   = "t3.medium"
      min_size        = 1
      max_size        = 10
      desired_size    = 1
      disk_size       = 20
      tags = {
        "Name"        = "monitoring"
        "Environment" = "benchmarking"
        "Cluster"     = "locust"
        "Terraform"   = "true"
      }
      labels = {
        "app"  = "locust"
        "role" = "monitoring"
      }
    }
  }
}
