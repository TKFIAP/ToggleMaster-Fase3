#!/bin/bash
# =============================================================================
# setup-lab.sh
# Prepara o cluster EKS depois do "terraform apply".
# Como rodar (a partir da raiz do projeto):  ./scripts/setup-lab.sh
# Nenhuma senha fica escrita aqui: os valores sao lidos na hora.
# =============================================================================
set -euo pipefail

PERFIL="lab"
REGIAO="us-east-1"
NAMESPACE="togglemaster"

# -----------------------------------------------------------------------------
# BLOCO 1 - Buscar as informacoes que o Terraform criou
# -----------------------------------------------------------------------------
echo ">>> [1/7] Lendo as saidas do Terraform..."
CLUSTER=$(terraform -chdir=terraform output -raw cluster_name)
REDIS=$(terraform -chdir=terraform output -raw redis_endpoint)
RDS_JSON=$(terraform -chdir=terraform output -json rds_endpoints)
AUTH_DB=$(echo "$RDS_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["auth"])')
FLAG_DB=$(echo "$RDS_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["flag"])')
TARGETING_DB=$(echo "$RDS_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["targeting"])')

# A senha dos bancos vem do terraform.tfvars (arquivo que NAO vai para o GitHub)
DB_USER="postgres"
DB_PASS=$(grep '^db_password' terraform/terraform.tfvars | cut -d'"' -f2)
if [ -z "$DB_PASS" ]; then
  echo "ERRO: nao encontrei db_password em terraform/terraform.tfvars"
  exit 1
fi

AUTH_URL="postgres://$DB_USER:$DB_PASS@$AUTH_DB:5432/auth_db?sslmode=require"
FLAG_URL="postgres://$DB_USER:$DB_PASS@$FLAG_DB:5432/flags_db?sslmode=require"
TARGETING_URL="postgres://$DB_USER:$DB_PASS@$TARGETING_DB:5432/targeting_db?sslmode=require"
echo "    Cluster: $CLUSTER"

# -----------------------------------------------------------------------------
# BLOCO 2 - Conectar o kubectl ao cluster
# -----------------------------------------------------------------------------
echo ">>> [2/7] Conectando o kubectl ao cluster..."
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGIAO" --profile "$PERFIL"
kubectl get nodes

# -----------------------------------------------------------------------------
# BLOCO 3 - Instalar ingress-nginx, metrics-server e ArgoCD
# -----------------------------------------------------------------------------
echo ">>> [3/7] Instalando ingress-nginx, metrics-server e ArgoCD..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/aws/deploy.yaml
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
echo "    Aguardando o ArgoCD ficar pronto (pode levar alguns minutos)..."
kubectl wait --for=condition=available deployment --all -n argocd --timeout=600s

# -----------------------------------------------------------------------------
# BLOCO 4 - Colocar o numero da conta AWS no ConfigMap (endereco da fila SQS)
# -----------------------------------------------------------------------------
echo ">>> [4/7] Conferindo o numero da conta no gitops/configmap.yaml..."
git pull --rebase
CONTA=$(aws sts get-caller-identity --query Account --output text --profile "$PERFIL")
if grep -q "CONTA_AWS" gitops/configmap.yaml; then
  sed -i "s/CONTA_AWS/$CONTA/" gitops/configmap.yaml
  git add gitops/configmap.yaml
  git commit -m "gitops: conta AWS do Lab no endereco da fila SQS"
  git push
  echo "    Conta $CONTA gravada e enviada para o GitHub."
else
  echo "    O ConfigMap ja tem o numero da conta. Nada a fazer."
fi

# -----------------------------------------------------------------------------
# BLOCO 5 - Criar o namespace e o Secret (direto no cluster, sem arquivo)
# -----------------------------------------------------------------------------
echo ">>> [5/7] Criando o Secret togglemaster-secrets..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
if kubectl get secret togglemaster-secrets -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "    O Secret ja existe. Mantendo o atual."
else
  MASTER_KEY=$(openssl rand -hex 24)
  kubectl create secret generic togglemaster-secrets -n "$NAMESPACE" \
    --from-literal=AUTH_DATABASE_URL="$AUTH_URL" \
    --from-literal=FLAG_DATABASE_URL="$FLAG_URL" \
    --from-literal=TARGETING_DATABASE_URL="$TARGETING_URL" \
    --from-literal=REDIS_URL="redis://$REDIS:6379" \
    --from-literal=MASTER_KEY="$MASTER_KEY" \
    --from-literal=SERVICE_API_KEY="pendente"
  echo "    Secret criado. A SERVICE_API_KEY sera gerada depois, com o gerar-api-key.sh."
fi

# -----------------------------------------------------------------------------
# BLOCO 6 - Criar as tabelas nos 3 bancos (um "visitante" temporario no cluster)
# -----------------------------------------------------------------------------
echo ">>> [6/7] Criando as tabelas nos bancos..."
criar_tabelas () {
  local nome=$1 url=$2 arquivo=$3
  echo "    Banco do $nome..."
  kubectl run "psql-$nome" -n "$NAMESPACE" --rm --attach --restart=Never \
    --image=postgres:17-alpine -- psql "$url" -c "$(cat "$arquivo")"
}
criar_tabelas auth      "$AUTH_URL"      auth-service/db/init.sql
criar_tabelas flag      "$FLAG_URL"      flag-service/db/init.sql
criar_tabelas targeting "$TARGETING_URL" targeting-service/db/init.sql

# -----------------------------------------------------------------------------
# BLOCO 7 - Entregar a "ordem de servico" ao ArgoCD
# -----------------------------------------------------------------------------
echo ">>> [7/7] Aplicando a Application do ArgoCD..."
kubectl apply -f argocd/application.yaml

echo ""
echo "=============================================================="
echo " Pronto! Proximos passos (estao no checklist):"
echo "  1. Atualizar os secrets do GitHub e ligar DEPLOY_ENABLED=true"
echo "  2. Rodar os 5 pipelines (Run workflow)"
echo "  3. Rodar ./scripts/gerar-api-key.sh"
echo "=============================================================="