#!/bin/bash
# setup-hosts.sh
# Adiciona os domínios .test no /etc/hosts para desenvolvimento local
# Uso: sudo bash local/setup-hosts.sh

set -euo pipefail

HOSTS_FILE="/etc/hosts"
MARKER_START="# justgu1 local dev — START"
MARKER_END="# justgu1 local dev — END"

ENTRIES=(
  "127.0.0.1 hericarealtor.test"
  "127.0.0.1 justgui.test"
  "127.0.0.1 n8n.justgui.test"
  "127.0.0.1 minio.justgui.test"
  "127.0.0.1 minio-console.justgui.test"
  "127.0.0.1 suporte.tyershop.test"
  "127.0.0.1 support.justgui.test"
  "127.0.0.1 evolution.justgui.test"
  "127.0.0.1 mail.justgui.test"
)

# Remove bloco anterior se existir
if grep -q "$MARKER_START" "$HOSTS_FILE"; then
  sed -i "/$MARKER_START/,/$MARKER_END/d" "$HOSTS_FILE"
fi

# Adiciona bloco novo
{
  echo ""
  echo "$MARKER_START"
  for entry in "${ENTRIES[@]}"; do
    echo "$entry"
  done
  echo "$MARKER_END"
} >> "$HOSTS_FILE"

echo "✓ /etc/hosts atualizado. Domínios disponíveis:"
for entry in "${ENTRIES[@]}"; do
  echo "  http://$(echo "$entry" | awk '{print $2}')"
done
