#!/bin/bash
# Corre migrações Medusa na base do tyershop (rede overlay `internal`, host tyershop_postgres).
# Pré-requisitos: stack tyershop a correr (pelo menos Postgres); .env na raiz com
# TYERSHOP_DB_USER, TYERSHOP_DB_PASSWORD, TYERSHOP_DB_NAME, TYERSHOP_BACKEND_TAG (opcional).
#
# Uso: cd /opt/infra-swarm && bash scripts/tyershop-db-migrate.sh

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

USER="${TYERSHOP_DB_USER:-tyershop}"
NAME="${TYERSHOP_DB_NAME:-tyershop}"
TAG="${TYERSHOP_BACKEND_TAG:-latest}"
IMAGE="ghcr.io/justgu1/tyershop-backend:${TAG}"

if [ -z "${TYERSHOP_DB_PASSWORD:-}" ]; then
  echo "Erro: TYERSHOP_DB_PASSWORD vazio no .env"
  exit 1
fi

ENC_PASS="$(python3 -c "import urllib.parse, os; print(urllib.parse.quote(os.environ.get('TYERSHOP_DB_PASSWORD',''), safe=''))")"
export DATABASE_URL="postgres://${USER}:${ENC_PASS}@tyershop_postgres:5432/${NAME}"

echo "======================================"
echo " Medusa db:migrate ($IMAGE)"
echo "======================================"

docker run --rm \
  --network internal \
  -e DATABASE_URL="$DATABASE_URL" \
  "$IMAGE" \
  npx medusa db:migrate

echo "✓ Migrações concluídas. Reinicia o backend: bash scripts/deploy-stack.sh tyershop"
