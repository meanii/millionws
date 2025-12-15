output "update_kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ap-south-1 --name ${aws_eks_cluster.eks.name}"
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "cluster_ca_certificate" {
  value = aws_eks_cluster.eks.certificate_authority[0].data
}

output "cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "cluster_auth_token" {
  value = data.aws_eks_cluster_auth.eks.token
}
