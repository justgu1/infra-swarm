# infra — justgu1

Infraestrutura Docker Swarm para os projetos justgu1. Um único repo que centraliza stacks, configs de Nginx, scripts de deploy e ambiente local.

---

## Projetos hospedados

| Projeto | Descrição | Stack |
|---|---|---|
| **hericarealtor** | Plataforma imobiliária — Laravel + scraper de listagens | `hericarealtor` |
| **tyershop** | E-commerce — Medusa + Astro + API Node | `tyershop` |
| **justgui.dev** | Site pessoal/portfólio — Go API + Astro | `justgui` |

### Serviços de suporte

| Serviço | Função | Stack |
|---|---|---|
| Nginx + Certbot | Reverse proxy centralizado + SSL automático | `core` |
| Portainer | Gerenciamento visual do Swarm | `portainer` |
| MinIO | Object storage S3-compatível (imagens, arquivos) | `storage` |
| n8n | Automações e webhooks | `automation` |
| Chatwoot | Suporte ao cliente (chat/email) | `comms` |
| Evolution API | Integração WhatsApp (via Chatwoot) | `comms` |

---

## Estrutura do repositório

```
infra/
├── core/
│   ├── nginx/
│   │   ├── nginx.conf          ← configuração base do Nginx
│   │   └── conf.d/             ← um arquivo .conf por domínio
│   └── wwp-updater/            ← serviço auxiliar WhatsApp version updater
├── local/
│   ├── docker-compose.yml      ← ambiente local completo
│   ├── nginx/conf.d/           ← confs Nginx para domínios .test
│   ├── setup-hosts.sh          ← adiciona entradas /etc/hosts
│   └── dev.sh                  ← atalhos para o ambiente local
├── stacks/
│   ├── core.yml                ← Nginx + Certbot
│   ├── portainer.yml           ← Portainer
│   ├── storage.yml             ← MinIO
│   ├── automation.yml          ← n8n
│   ├── comms.yml               ← Chatwoot + Evolution API
│   ├── hericarealtor.yml       ← Laravel PHP-FPM + PostgreSQL + Redis
│   ├── tyershop.yml            ← Medusa + Astro + API + PostgreSQL + Redis
│   └── justgui.yml             ← Go API + Astro
├── scripts/
│   ├── bootstrap-vps.sh        ← passo 1: prepara a VPS do zero
│   ├── certbot-init.sh         ← passo 2: emite certificados SSL
│   └── deploy-stack.sh         ← passo 3: sobe um ou todos os stacks
├── .env.example                ← template de variáveis (sem valores reais)
└── .gitignore                  ← exclui .env, apps/ e arquivos de SO
```

### Redes overlay (Swarm)

| Rede | Uso |
|---|---|
| `proxy` | Nginx → todos os serviços com porta exposta |
| `internal` | Comunicação interna entre serviços (DBs, Redis) |

---

## Pré-requisitos

- VPS com Ubuntu 22.04+ e acesso root via SSH
- Chave SSH configurada no servidor
- DNS dos domínios apontando para o IP da VPS **antes** de emitir certificados

---

## Deploy inicial na VPS

### 1. Bootstrap

Conecte na VPS e execute:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/justgu1/infra/main/scripts/bootstrap-vps.sh)
```

O script faz automaticamente:
- Atualiza o sistema e instala dependências (`curl`, `git`, `ufw`)
- Instala o Docker e habilita o serviço
- Inicializa o Docker Swarm com o IP público da VPS
- Cria as redes overlay `proxy` e `internal`
- Cria os volumes do Certbot (`certbot_certs`, `certbot_www`)
- Clona o repositório em `/opt/infra-swarm`
- Configura o firewall (portas 22, 80, 443)

### 2. Configurar variáveis de ambiente

```bash
cd /opt/infra-swarm
cp .env.example .env
nano .env   # preencha todos os valores marcados com "changeme"
```

> ⚠️ **Nunca commite o `.env`** — ele está no `.gitignore` e contém segredos reais.
> Use o `.env.example` como referência; ele só contém placeholders.

### 3. Emitir certificados SSL

> Pré-requisito: DNS já propagado para o IP da VPS.

```bash
bash scripts/certbot-init.sh
```

O script:
- Sobe um Nginx temporário para responder ao challenge HTTP-01
- Emite certificados Let's Encrypt para todos os domínios configurados
- Baixa as configurações SSL recomendadas (DH params, options-ssl-nginx.conf)
- Remove o container temporário

### 4. Subir todos os stacks

```bash
bash scripts/deploy-stack.sh
```

Ordem de deploy: `core → portainer → storage → automation → comms → hericarealtor → tyershop → justgui`

---

## Deploy de stack individual

```bash
bash scripts/deploy-stack.sh core
bash scripts/deploy-stack.sh storage
bash scripts/deploy-stack.sh automation
bash scripts/deploy-stack.sh comms
bash scripts/deploy-stack.sh hericarealtor
bash scripts/deploy-stack.sh tyershop
bash scripts/deploy-stack.sh justgui
```

---

## Ambiente local (desenvolvimento)

```bash
cd local

# 1. Adicionar entradas no /etc/hosts (apenas na primeira vez)
bash setup-hosts.sh

# 2. Ajustar variáveis locais
cp .env.local.example .env.local  # ou edite o .env.local existente

# 3. Subir o ambiente
docker compose up -d

# Tyershop (Medusa + Astro + API) — requer clone em apps/tyershop
docker compose --env-file .env.local --profile tyershop up -d
# ou: bash local/dev.sh up tyershop  → http://tyershop.test
```

Domínios locais usam o sufixo `.test` e são resolvidos via `/etc/hosts`.

---

## Atualizar um stack em produção

```bash
cd /opt/infra-swarm
git pull
bash scripts/deploy-stack.sh <nome-do-stack>
```

O Docker Swarm faz rolling update sem downtime nos serviços com réplicas > 1.

---

## Migrar para outro servidor

1. Provisione a nova VPS com o mesmo OS
2. Aponte o DNS para o novo IP (mantenha o antigo no ar durante a transição)
3. Execute o bootstrap no novo servidor
4. Copie o `.env` do servidor anterior (nunca via git):
   ```bash
   scp usuario@servidor-antigo:/opt/infra-swarm/.env /opt/infra-swarm/.env
   ```
5. Restaure os volumes com dados persistentes (PostgreSQL, MinIO):
   ```bash
   # Exemplo para PostgreSQL — adapte por stack
   docker exec <container_db> pg_dumpall -U <usuario> > backup.sql
   # No novo servidor:
   docker exec -i <container_db_novo> psql -U <usuario> < backup.sql
   ```
6. Emita novos certificados SSL: `bash scripts/certbot-init.sh`
7. Suba os stacks: `bash scripts/deploy-stack.sh`
8. Valide e redirecione o DNS

---

## Escalar um serviço

```bash
# Escalar o worker do hericarealtor para 3 réplicas
docker service scale hericarealtor_worker=3

# Verificar réplicas ativas
docker service ls
docker service ps hericarealtor_worker
```

Para tornar permanente, ajuste `deploy.replicas` no stack `.yml` e faça redeploy.

---

## Adicionar um novo projeto

1. Criar entrada DNS apontando para a VPS
2. Criar `core/nginx/conf.d/novoprojeto.conf` (use um conf existente como modelo)
3. Criar `stacks/novoprojeto.yml`
4. Adicionar os domínios em `scripts/certbot-init.sh`
5. Adicionar as variáveis necessárias em `.env.example` (sem valores reais)
6. Commit e push
7. Na VPS: `git pull && bash scripts/deploy-stack.sh novoprojeto`

---

## Segurança

- **`.env` nunca vai ao git** — está no `.gitignore`. Use `.env.example` com placeholders.
- **Segredos em produção** gerenciados exclusivamente via `.env` no servidor, fora do repositório.
- **Docker secrets**: o stack `tyershop` usa secrets externos do Swarm para credenciais críticas.
- **Firewall (UFW)** habilitado pelo bootstrap: apenas portas 22, 80 e 443 abertas.
- **SSL automático** via Certbot/Let's Encrypt com renovação a cada 12h.
- **Redes internas** (`internal`) isolam bancos de dados e Redis — nunca expostos ao `proxy`.
- **Portainer** restrito por senha e acessível apenas via HTTPS.
- Rotacione segredos periodicamente e nunca os compartilhe em issues, PRs ou logs.

### Tyershop (dados e API)

- **Checkout / Mercado Pago**: `MERCADOPAGO_ACCESS_TOKEN` só em variável de ambiente ou Docker secret; nunca no frontend.
- **API Node (`tyershop_api`)**: com `CORS_ORIGIN` definido (ex.: `URL_TYERSHOP` em produção), só o storefront indicado pode chamar `/api/*`. Em dev local, sem `CORS_ORIGIN`, o modo permissivo do CORS permanece para facilitar testes.
- **Medusa**: `JWT_SECRET` e `COOKIE_SECRET` obrigatórios fortes em produção; `STORE_CORS` / `AUTH_CORS` devem listar apenas os domínios reais da loja e do admin.
- **Nginx local (`tyershop.test`)**: cabeçalhos `X-Content-Type-Options`, `Referrer-Policy`, `X-Frame-Options`, `Permissions-Policy` e rate limit em `/api/` (zona `tyershop_api`).
- **Webhook MP** (`/api/webhook`): validar assinatura do provedor antes de alterar pedido; hoje o handler é esqueleto — tratar como pendência crítica antes de ir a produção.

---

## Apps (repos externos)

Os repos de aplicação são clonados manualmente na pasta `apps/` (gitignored):

```bash
git clone git@github.com:justgu1/hericarealtor.git apps/hericarealtor
git clone git@github.com:justgu1/tyershop.git      apps/tyershop
git clone git@github.com:justgu1/justgui.dev.git   apps/justgui
```
