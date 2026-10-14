output "rds_endpoints" {
  description = "Endereco de cada banco PostgreSQL"
  value       = { for name, db in aws_db_instance.postgres : name => db.address }
}