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