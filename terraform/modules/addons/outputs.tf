output "argocd_namespace" {
  description = "Namespace onde o ArgoCD foi instalado"
  value       = helm_release.argocd.namespace
}
