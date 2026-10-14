module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
}

# Pega a LabRole, que ja existe no AWS Academy (o Terraform nao pode criar permissoes no Lab)
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

module "eks" {
  source           = "./modules/eks"
  project_name     = var.project_name
  cluster_role_arn = data.aws_iam_role.lab_role.arn
  node_role_arn    = data.aws_iam_role.lab_role.arn
  subnet_ids       = module.networking.public_subnet_ids
}

module "databases" {
  source             = "./modules/databases"
  project_name       = var.project_name
  vpc_id             = module.networking.vpc_id
  vpc_cidr_block     = module.networking.vpc_cidr_block
  private_subnet_ids = module.networking.private_subnet_ids
  db_username        = var.db_username
  db_password        = var.db_password
}

module "messaging" {
  source       = "./modules/messaging"
  project_name = var.project_name
}

module "ecr" {
  source = "./modules/ecr"
  repository_names = [
    "auth-service",
    "flag-service",
    "targeting-service",
    "evaluation-service",
    "analytics-service",
  ]
}