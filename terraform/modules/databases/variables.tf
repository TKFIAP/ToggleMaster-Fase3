variable "project_name" {
  description = "Nome do projeto, usado como prefixo nos nomes dos recursos"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC onde os bancos vao ficar"
  type        = string
}

variable "vpc_cidr_block" {
  description = "Faixa de enderecos da VPC, usada para liberar o acesso aos bancos so de dentro da rede"
  type        = string
}

variable "private_subnet_ids" {
  description = "Subnets privadas onde os bancos vao ficar"
  type        = list(string)
}

variable "db_username" {
  description = "Usuario administrador dos bancos PostgreSQL"
  type        = string
}

variable "db_password" {
  description = "Senha dos bancos PostgreSQL"
  type        = string
  sensitive   = true
}