#!/bin/bash
# deploy-stack.sh
# Faz deploy de um ou todos os stacks no Docker Swarm
# Uso:
#   bash scripts/deploy-stack.sh          → todos os stacks
#   bash scripts/deploy-stack.sh core     → apenas o stack core

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

source "$INFRA_DIR/.env"
export $(grep -v '^#' "$INFRA_DIR/.env" | xargs)

ALL_STACKS=(core portainer storage automation comms hericarealtor justgui)

deploy_stack() {
  local name="$1"
  local file="$INFRA_DIR/stacks/${name}.yml"

  if [ ! -f "$file" ]; then
    echo "⚠️  Stack não encontrado: $file"
    return 1
  fi

  echo "→ Deploying stack: $name"
  docker stack deploy --with-registry-auth --compose-file "$file" "$name"
  echo "✓ Stack $name deployado."
}

if [ $# -eq 0 ]; then
  echo "======================================"
  echo " Deploy — todos os stacks"
  echo "======================================"
  for stack in "${ALL_STACKS[@]}"; do
    deploy_stack "$stack"
    sleep 5
  done
else
  echo "======================================"
  echo " Deploy — stack: $1"
  echo "======================================"
  deploy_stack "$1"
fi

echo ""
echo "Status dos stacks:"
docker stack ls
