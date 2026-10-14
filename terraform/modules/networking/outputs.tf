output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs das subnets publicas (maquinas do EKS e Load Balancer)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas (RDS e Redis)"
  value       = aws_subnet.private[*].id
}

output "vpc_cidr_block" {
  description = "Faixa de enderecos da VPC"
  value       = aws_vpc.main.cidr_block
}