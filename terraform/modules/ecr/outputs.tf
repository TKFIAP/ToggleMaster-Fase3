output "repository_urls" {
  description = "Endereco de cada repositorio de imagens"
  value       = { for name, repo in aws_ecr_repository.services : name => repo.repository_url }
}