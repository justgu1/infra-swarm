#!/bin/bash
# certbot-init.sh
# Emite certificados SSL para todos os domínios via Let's Encrypt
# Deve ser executado APÓS o bootstrap e ANTES do deploy completo
# Uso: bash scripts/certbot-init.sh
# Pré-requisito: .env preenchido, DNS apontando para a VPS

set -euo pipefail

DEPLOY_PATH="/opt/infra-swarm"

# Carregar variáveis
source "$DEPLOY_PATH/.env"

DOMAINS=(
  "hericarealtor.com"
  "www.hericarealtor.com"
  "justgui.dev"
  "www.justgui.dev"
  "n8n.justgui.dev"
  "minio.justgui.dev"
  "minio-console.justgui.dev"
  "support.justgui.dev"
  "homolog.tyershop.com"
  "www.homolog.tyershop.com"
  "suporte.tyershop.com"
  "evolution.justgui.dev"
  "portainer.justgui.dev"
)

echo "======================================"
echo " Emissão de certificados SSL"
echo "======================================"
echo "Email: $CERTBOT_EMAIL"
echo ""

# Passo 1: Subir nginx temporário apenas com HTTP (sem SSL)
echo "[1/3] Subindo nginx temporário (HTTP)..."

# Nginx temporário que só serve o challenge
docker run -d --name nginx_temp \
  -p 80:80 \
  -v certbot_www:/var/www/certbot \
  nginx:1.27-alpine \
  sh -c "mkdir -p /etc/nginx/conf.d && echo '
server {
  listen 80 default_server;
  location /.well-known/acme-challenge/ { root /var/www/certbot; }
  location / { return 200 \"ok\"; }
}' > /etc/nginx/conf.d/default.conf && nginx -g \"daemon off;\""

sleep 3

# Passo 2: Emitir certificados
echo "[2/3] Emitindo certificados..."

for domain in "${DOMAINS[@]}"; do
  echo "  → Emitindo: $domain"
  docker run --rm \
    -v certbot_certs:/etc/letsencrypt \
    -v certbot_www:/var/www/certbot \
    certbot/certbot certonly \
      --webroot \
      --webroot-path=/var/www/certbot \
      --email "$CERTBOT_EMAIL" \
      --agree-tos \
      --no-eff-email \
      --non-interactive \
      -d "$domain" || echo "  ⚠️  Falha em $domain (verifique DNS)"
done

# Baixar parâmetros DH e opções SSL recomendadas
echo "  → Baixando configurações SSL recomendadas..."
docker run --rm \
  --entrypoint sh \
  -v certbot_certs:/etc/letsencrypt \
  certbot/certbot \
  -c "
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf \
      -o /etc/letsencrypt/options-ssl-nginx.conf;
    openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048 2>/dev/null;
  "

# Passo 3: Remover nginx temporário
echo "[3/3] Removendo nginx temporário..."
docker stop nginx_temp && docker rm nginx_temp

echo ""
echo "======================================"
echo " Certificados emitidos!"
echo "======================================"
echo ""
echo "Próximo passo:"
echo "  bash $DEPLOY_PATH/scripts/deploy-stack.sh"
