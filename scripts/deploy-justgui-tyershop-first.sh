#!/bin/bash
# Primeiro deploy dos stacks justgui + tyershop (homolog) numa VPS com Swarm já inicializado.
# Uso (na VPS como root):
#   cd /opt/infra-swarm
#   bash scripts/deploy-justgui-tyershop-first.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

cd "$INFRA_DIR"

if [ ! -f .env ]; then
  echo "Erro: crie .env a partir de .env.example antes de continuar."
  exit 1
fi

echo "→ Deploy stack core (nginx)"
bash scripts/deploy-stack.sh core

echo "→ Secrets tyershop"
bash scripts/tyershop-sync-secrets.sh

echo "→ Migração DB tyershop"
bash scripts/tyershop-db-migrate.sh

echo "→ Deploy stack tyershop"
bash scripts/deploy-stack.sh tyershop

echo "→ Deploy stack justgui"
bash scripts/deploy-stack.sh justgui

echo ""
echo "Status:"
docker service ls | grep -E 'tyershop|justgui' || true
