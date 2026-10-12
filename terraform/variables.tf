variable "project_name" {
  description = "Nome do projeto, usado como prefixo nos nomes dos recursos"
  type        = string
  default     = "togglemaster"
}

variable "aws_region" {
  description = "Regiao da AWS onde tudo sera criado"
  type        = string
  default     = "us-east-1"
}

variable "db_username" {
  description = "Usuario administrador dos bancos PostgreSQL (RDS)"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Senha dos bancos PostgreSQL (RDS). Valor definido no terraform.tfvars, que nao vai para o GitHub"
  type        = string
  sensitive   = true
}