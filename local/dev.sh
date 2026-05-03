#!/bin/bash
# dev.sh
# Gerencia o ambiente local de desenvolvimento
# Uso:
#   bash local/dev.sh up              → sobe stack base (sem perfis de app)
#   bash local/dev.sh up tyershop     → sobe perfil tyershop (+ base já em execução)
#   bash local/dev.sh down            → derruba tudo
#   bash local/dev.sh restart         → reinicia stack base
#   bash local/dev.sh logs [serviço] → acompanha logs
#   bash local/dev.sh ps              → lista containers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMD=${1:-up}
ARG2=${2:-}

cd "$SCRIPT_DIR"

if [ "$CMD" = "up" ] && [ -n "$ARG2" ]; then
  case "$ARG2" in
    tyershop | hericarealtor | justgui)
      docker compose --env-file .env.local --profile "$ARG2" up -d
      exit 0
      ;;
    *)
      echo "Perfil desconhecido: $ARG2 (use: tyershop, hericarealtor, justgui)"
      exit 1
      ;;
  esac
fi

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
    echo "  Apps (clone em apps/ + perfil Docker):"
    echo "  bash local/dev.sh up tyershop      → http://tyershop.test"
    echo "  bash local/dev.sh up hericarealtor → http://hericarealtor.test"
    echo "  bash local/dev.sh up justgui       → http://justgui.test"
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
    echo "     bash local/dev.sh up tyershop"
    exit 1
    ;;
esac
