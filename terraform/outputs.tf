output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_name
}

output "configure_kubectl" {
  description = "Comando para conectar o kubectl do seu PC ao cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region} --profile lab"
}

output "rds_endpoints" {
  description = "Endereco de cada banco PostgreSQL"
  value       = module.databases.rds_endpoints
}

output "redis_endpoint" {
  description = "Endereco do Redis"
  value       = module.databases.redis_endpoint
}

output "dynamodb_table_name" {
  description = "Nome da tabela do DynamoDB"
  value       = module.databases.dynamodb_table_name
}

output "sqs_queue_url" {
  description = "Endereco da fila SQS"
  value       = module.messaging.queue_url
}

output "ecr_repository_urls" {
  description = "Endereco de cada repositorio de imagens"
  value       = module.ecr.repository_urls
}