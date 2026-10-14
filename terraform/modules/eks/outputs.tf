output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endereco do cluster, usado pelo kubectl"
  value       = aws_eks_cluster.main.endpoint
}