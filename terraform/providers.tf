terraform {
  required_version = ">= 1.6"
  required_providers {
    aws  = { source = "hashicorp/aws", version = "~> 6.0" }
    helm = { source = "hashicorp/helm", version = "~> 3.0" }
    time = { source = "hashicorp/time", version = "~> 0.13" }
  }

  backend "s3" {}
}

provider "aws" {
  region  = var.aws_region
  profile = "lab"
}

# O Helm instala programas dentro do cluster EKS.
# Ele se conecta ao cluster com os dados que o modulo eks devolve,
# e pede um "passe" temporario ao comando "aws eks get-token" (perfil lab).
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region, "--profile", "lab"]
    }
  }
}