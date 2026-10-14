output "rds_endpoints" {
  description = "Endereco de cada banco PostgreSQL"
  value       = { for name, db in aws_db_instance.postgres : name => db.address }
}

output "redis_endpoint" {
  description = "Endereco do Redis"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "dynamodb_table_name" {
  description = "Nome da tabela do DynamoDB"
  value       = aws_dynamodb_table.analytics.name
}