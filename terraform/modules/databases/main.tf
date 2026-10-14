# Lista dos 3 bancos: o apelido de cada um e o nome do banco la dentro
locals {
  databases = {
    auth      = "auth_db"
    flag      = "flags_db"
    targeting = "targeting_db"
  }
}

# O porteiro dos bancos: so deixa entrar quem vem de dentro da VPC, pela porta 5432
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Permite acesso ao PostgreSQL somente de dentro da VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# As ruas onde os bancos podem morar: as subnets privadas
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnets"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnets"
  }
}

# Os 3 bancos PostgreSQL, um para cada item da lista acima
resource "aws_db_instance" "postgres" {
  for_each = local.databases

  identifier     = "${var.project_name}-${each.key}-db"
  engine         = "postgres"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = each.value
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az                = false
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  tags = {
    Name = "${var.project_name}-${each.key}-db"
  }
}