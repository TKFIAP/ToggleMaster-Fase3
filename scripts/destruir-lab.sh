#!/bin/bash
# =============================================================================
# destruir-lab.sh
# Apaga TUDO no fim da sessao do Lab, na ordem certa.
# Como rodar (a partir da raiz do projeto):  ./scripts/destruir-lab.sh
# =============================================================================
set -euo pipefail

PERFIL="lab"
REGIAO="us-east-1"

# -----------------------------------------------------------------------------
# PASSO 1 - Remover o ingress-nginx
# O Load Balancer foi criado pelo Kubernetes, e nao pelo Terraform.
# Se ele continuar existindo, o terraform destroy trava ao apagar a rede (VPC).
# -----------------------------------------------------------------------------
echo ">>> [1/3] Removendo o ingress-nginx (apaga o Load Balancer criado pelo Kubernetes)..."
kubectl delete namespace ingress-nginx --ignore-not-found --timeout=300s

# -----------------------------------------------------------------------------
# PASSO 2 - Esperar o Load Balancer sumir da AWS
# -----------------------------------------------------------------------------
echo ">>> [2/3] Aguardando o Load Balancer sumir da AWS..."
for tentativa in $(seq 1 30); do
  QTD=$(aws elbv2 describe-load-balancers --region "$REGIAO" --profile "$PERFIL" \
    --query 'length(LoadBalancers)' --output text)
  if [ "$QTD" = "0" ]; then
    echo "    Load Balancer removido."
    break
  fi
  echo "    Tentativa $tentativa: ainda existe(m) $QTD Load Balancer(s). Aguardando 10s..."
  sleep 10
done

# -----------------------------------------------------------------------------
# PASSO 3 - Apagar toda a infraestrutura criada pelo Terraform
# -----------------------------------------------------------------------------
echo ">>> [3/3] Rodando o terraform destroy (vai pedir confirmacao: digite yes)..."
terraform -chdir=terraform destroy

echo ""
echo "=============================================================="
echo " Infraestrutura apagada. Nao esqueca:"
echo "  1. No GitHub: DEPLOY_ENABLED = false"
echo "  2. No painel do Lab: conferir se o saldo parou de subir"
echo "=============================================================="