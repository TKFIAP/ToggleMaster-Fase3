terraform {
  required_providers {
    helm = { source = "hashicorp/helm" }
  }
}

# Le a "ordem de servico" do ArgoCD (argocd/application.yaml)
locals {
  argocd_app = yamldecode(file(var.argocd_application_file))
}

# Porta de entrada da aplicacao: cria um Network Load Balancer na AWS
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.15.1"
  namespace        = "ingress-nginx"
  create_namespace = true

  values = [yamlencode({
    controller = {
      service = {
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
        }
      }
    }
  })]
}

# Mede o uso de CPU e memoria dos pods (necessario para o HPA)
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.14.0"
  namespace  = "kube-system"
}

# ArgoCD: o "zelador" do GitOps
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.10.5"
  namespace        = "argocd"
  create_namespace = true

  # Desliga dois componentes que o projeto nao usa (login externo e notificacoes)
  values = [yamlencode({
    dex           = { enabled = false }
    notifications = { enabled = false }
  })]
}

# Entrega ao ArgoCD a Application definida em argocd/application.yaml
resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.7"
  namespace  = "argocd"

  values = [yamlencode({
    applications = {
      (local.argocd_app.metadata.name) = merge(local.argocd_app.spec, {
        namespace = local.argocd_app.metadata.namespace
      })
    }
  })]

  depends_on = [helm_release.argocd, helm_release.ingress_nginx]
}