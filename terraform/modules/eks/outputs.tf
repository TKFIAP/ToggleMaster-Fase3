output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endereco do cluster, usado pelo kubectl"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Certificado do cluster, usado pelo Helm para confiar no cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}