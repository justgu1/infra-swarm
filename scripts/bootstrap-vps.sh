#!/bin/bash
# bootstrap-vps.sh
# Prepara a VPS do zero: Docker, Swarm, redes overlay, volumes Certbot
# Uso: bash scripts/bootstrap-vps.sh

set -euo pipefail

DEPLOY_PATH="/opt/infra-swam"
REPO_URL="git@github.com:justgu1/infra-swam.git"

echo "======================================"
echo " Bootstrap VPS — justgu1 infra"
echo "======================================"

# 1. Atualizar sistema
echo "[1/7] Atualizando sistema..."
apt-get update -qq && apt-get upgrade -y -qq

# 2. Instalar dependências
echo "[2/7] Instalando dependências..."
apt-get install -y -qq \
  curl git ca-certificates gnupg lsb-release ufw

# 3. Instalar Docker
echo "[3/7] Instalando Docker..."
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
  echo "Docker instalado: $(docker --version)"
else
  echo "Docker já instalado: $(docker --version)"
fi

# 4. Inicializar Docker Swarm
echo "[4/7] Inicializando Docker Swarm..."
if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "active"; then
  PUBLIC_IP=$(curl -s ifconfig.me)
  docker swarm init --advertise-addr "$PUBLIC_IP"
  echo "Swarm iniciado. IP: $PUBLIC_IP"
else
  echo "Swarm já ativo."
fi

# 5. Criar redes overlay
echo "[5/7] Criando redes overlay..."
docker network create --driver overlay --attachable proxy 2>/dev/null || echo "Rede 'proxy' já existe."
docker network create --driver overlay --attachable internal 2>/dev/null || echo "Rede 'internal' já existe."

# 6. Criar volumes para Certbot
echo "[6/7] Criando volumes Certbot..."
docker volume create certbot_certs 2>/dev/null || echo "Volume 'certbot_certs' já existe."
docker volume create certbot_www 2>/dev/null || echo "Volume 'certbot_www' já existe."

# 7. Clonar/atualizar repositório
echo "[7/7] Configurando repositório..."
if [ -d "$DEPLOY_PATH/.git" ]; then
  echo "Repositório já existe. Atualizando..."
  git -C "$DEPLOY_PATH" pull
else
  echo "Clonando repositório..."
  git clone "$REPO_URL" "$DEPLOY_PATH"
fi

# Configurar .env
if [ ! -f "$DEPLOY_PATH/.env" ]; then
  cp "$DEPLOY_PATH/.env.example" "$DEPLOY_PATH/.env"
  echo ""
  echo "⚠️  IMPORTANTE: Edite o arquivo $DEPLOY_PATH/.env antes de continuar!"
  echo "   nano $DEPLOY_PATH/.env"
fi

# Configurar Firewall
echo "Configurando UFW..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo ""
echo "======================================"
echo " Bootstrap concluído!"
echo "======================================"
echo ""
echo "Próximos passos:"
echo "  1. nano $DEPLOY_PATH/.env          (preencher variáveis)"
echo "  2. bash $DEPLOY_PATH/scripts/certbot-init.sh  (emitir certificados SSL)"
echo "  3. bash $DEPLOY_PATH/scripts/deploy-stack.sh  (subir todos os stacks)"
