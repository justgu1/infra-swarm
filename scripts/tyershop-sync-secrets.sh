#!/bin/bash
# Cria os Docker Swarm secrets do tyershop a partir do .env na raiz do repo.
# O stack tyershop.yml usa secrets "external: true" — o Swarm não lê o .env sozinho.
#
# Uso (na VPS, como root):
#   cd /opt/infra-swarm
#   bash scripts/tyershop-sync-secrets.sh
#
# Se o secret já existir, não altera (Docker não permite atualizar valor in-place).
# Para trocar a password do Redis (exemplo):
#   docker stack rm tyershop
#   docker secret rm tyershop_redis_password
#   bash scripts/tyershop-sync-secrets.sh
#   bash scripts/deploy-stack.sh tyershop

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${INFRA_DIR}/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Erro: não existe $ENV_FILE"
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

trim() {
  printf '%s' "$1" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

secret_exists() {
  docker secret inspect "$1" &>/dev/null
}

create_secret() {
  local swarm_name=$1
  local value
  value=$(trim "$2")
  if [ -z "$value" ]; then
    echo "⚠️  Ignorado: $swarm_name (valor vazio no .env)"
    return 0
  fi
  if secret_exists "$swarm_name"; then
    echo "⏭  $swarm_name já existe — mantido. Para substituir: docker stack rm tyershop && docker secret rm $swarm_name && reexecutar este script."
    return 0
  fi
  printf '%s' "$value" | docker secret create "$swarm_name" -
  echo "✓ Criado secret: $swarm_name"
}

# O stack exige este secret; sem MERCADOPAGO_ACCESS_TOKEN no .env usamos placeholder (API sobe; checkout MP falha até configurares).
create_mercadopago_secret() {
  local value
  value=$(trim "${MERCADOPAGO_ACCESS_TOKEN:-}")
  if [ -z "$value" ]; then
    value="__MERCADOPAGO_TOKEN_UNSET__"
    echo "ℹ️  MERCADOPAGO_ACCESS_TOKEN vazio → secret placeholder (define token real e recria o secret para ativar checkout)."
  fi
  if secret_exists tyershop_mercadopago_access_token; then
    echo "⏭  tyershop_mercadopago_access_token já existe — mantido. Para token novo: docker stack rm tyershop && docker secret rm tyershop_mercadopago_access_token && reexecutar este script."
    return 0
  fi
  printf '%s' "$value" | docker secret create tyershop_mercadopago_access_token -
  echo "✓ Criado secret: tyershop_mercadopago_access_token"
}

AWS_SECRET_VALUE="${TYERSHOP_AWS_SECRET_ACCESS_KEY:-${MINIO_ROOT_PASSWORD:-}}"

echo "======================================"
echo " Tyershop — sync secrets ← .env"
echo "======================================"

create_secret tyershop_db_password "${TYERSHOP_DB_PASSWORD:-}"
create_secret tyershop_redis_password "${TYERSHOP_REDIS_PASSWORD:-}"
create_secret tyershop_jwt_secret "${TYERSHOP_JWT_SECRET:-}"
create_secret tyershop_cookie_secret "${TYERSHOP_COOKIE_SECRET:-}"
create_mercadopago_secret
create_secret tyershop_aws_secret_access_key "$AWS_SECRET_VALUE"

echo ""
echo "Secrets tyershop no Swarm:"
docker secret ls --filter name=tyershop --format 'table {{.Name}}\t{{.CreatedAt}}'
