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

# O porteiro do Redis: so deixa entrar quem vem de dentro da VPC, pela porta 6379
resource "aws_security_group" "redis" {
  name        = "${var.project_name}-redis-sg"
  description = "Permite acesso ao Redis somente de dentro da VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
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
    Name = "${var.project_name}-redis-sg"
  }
}

# As ruas onde o Redis pode morar: as subnets privadas
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-redis-subnets"
  subnet_ids = var.private_subnet_ids
}

# O Redis (cache do evaluation-service)
resource "aws_elasticache_cluster" "redis" {
  cluster_id         = "${var.project_name}-redis"
  engine             = "redis"
  node_type          = "cache.t3.micro"
  num_cache_nodes    = 1
  port               = 6379
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]
}

# A tabela do DynamoDB (historico de avaliacoes do analytics-service)
resource "aws_dynamodb_table" "analytics" {
  name         = "ToggleMasterAnalytics"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }
}