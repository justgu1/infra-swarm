#!/bin/bash
# dev.sh
# Gerencia o ambiente local de desenvolvimento
# Uso:
#   bash local/dev.sh up       → sobe tudo
#   bash local/dev.sh down     → derruba tudo
#   bash local/dev.sh restart  → reinicia tudo
#   bash local/dev.sh logs     → acompanha logs
#   bash local/dev.sh ps       → lista containers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMD=${1:-up}

cd "$SCRIPT_DIR"

case "$CMD" in
  up)
    if ! grep -q "hericarealtor.test" /etc/hosts 2>/dev/null; then
      echo "⚠️  Domínios .test não encontrados em /etc/hosts."
      echo "   Execute: sudo bash local/setup-hosts.sh"
      echo ""
    fi
    echo "→ Subindo ambiente local (infra)..."
    docker compose --env-file .env.local up -d --remove-orphans
    echo ""
    echo "✓ Infra disponível:"
    echo "  http://n8n.justgui.test"
    echo "  http://minio-console.justgui.test  (minioadmin / minioadmin123)"
    echo "  http://support.justgui.test"
    echo "  http://evolution.justgui.test"
    echo "  http://mail.justgui.test           (Mailpit)"
    echo ""
    echo "  Apps (requer Dockerfile + imagem):"
    echo "  bash local/dev.sh up hericarealtor → http://hericarealtor.test"
    echo "  bash local/dev.sh up justgui       → http://justgui.test"
    ;;
  up\ hericarealtor|up-hericarealtor)
    docker compose --env-file .env.local --profile hericarealtor up -d
    ;;
  up\ justgui|up-justgui)
    docker compose --env-file .env.local --profile justgui up -d
    ;;
  down)
    echo "→ Derrubando ambiente local..."
    docker compose --env-file .env.local down
    ;;
  restart)
    docker compose --env-file .env.local down
    docker compose --env-file .env.local up -d --remove-orphans
    ;;
  logs)
    docker compose --env-file .env.local logs -f ${2:-}
    ;;
  ps)
    docker compose --env-file .env.local ps
    ;;
  *)
    echo "Uso: bash local/dev.sh [up|down|restart|logs|ps]"
    exit 1
    ;;
esac
