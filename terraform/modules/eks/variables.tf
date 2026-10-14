variable "project_name" {
  description = "Nome do projeto, usado como prefixo nos nomes dos recursos"
  type        = string
}

variable "cluster_role_arn" {
  description = "Permissao (IAM Role) usada pelo cluster. No Academy, a LabRole"
  type        = string
}

variable "node_role_arn" {
  description = "Permissao (IAM Role) usada pelas maquinas do cluster. No Academy, a LabRole"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets onde o cluster e as maquinas vao ficar"
  type        = list(string)
}

variable "node_instance_type" {
  description = "Tamanho das maquinas do cluster"
  type        = string
  default     = "t3.medium"
}

variable "node_count" {
  description = "Quantidade de maquinas do cluster"
  type        = number
  default     = 2
}