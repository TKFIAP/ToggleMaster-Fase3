#!/bin/bash
# =============================================================================
# gerar-api-key.sh
# Gera a SERVICE_API_KEY no auth-service e entrega ao evaluation-service.
# Rodar DEPOIS que o ArgoCD subiu os servicos (pods em Running).
# Como rodar (a partir da raiz do projeto):  ./scripts/gerar-api-key.sh
# =============================================================================
set -euo pipefail

NAMESPACE="togglemaster"

# 1. Esperar o auth-service estar pronto
echo ">>> [1/4] Aguardando o auth-service ficar pronto..."
kubectl rollout status deployment/auth-service -n "$NAMESPACE" --timeout=300s

# 2. Ler a MASTER_KEY que o setup-lab.sh guardou no Secret
MASTER_KEY=$(kubectl get secret togglemaster-secrets -n "$NAMESPACE" \
  -o jsonpath='{.data.MASTER_KEY}' | base64 -d)

# 3. Abrir um tunel temporario ate o auth-service e pedir uma chave nova
echo ">>> [2/4] Pedindo uma chave nova ao auth-service..."
kubectl port-forward svc/auth-service 8001:8001 -n "$NAMESPACE" >/dev/null 2>&1 &
TUNEL=$!
trap 'kill $TUNEL 2>/dev/null' EXIT
sleep 5

RESPOSTA=$(curl -s -X POST http://localhost:8001/admin/keys \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -d '{"name": "evaluation-service"}')
CHAVE=$(echo "$RESPOSTA" | python3 -c 'import json,sys; print(json.load(sys.stdin)["key"])')

# 4. Guardar a chave no Secret e reiniciar o evaluation-service para ele ler o valor novo
echo ">>> [3/4] Gravando a chave no Secret..."
kubectl patch secret togglemaster-secrets -n "$NAMESPACE" \
  -p "{\"stringData\":{\"SERVICE_API_KEY\":\"$CHAVE\"}}"

echo ">>> [4/4] Reiniciando o evaluation-service..."
kubectl rollout restart deployment/evaluation-service -n "$NAMESPACE"
kubectl rollout status deployment/evaluation-service -n "$NAMESPACE" --timeout=300s

echo ""
echo "Pronto! A SERVICE_API_KEY foi gerada e entregue ao evaluation-service."