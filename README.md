# justgu1 — Infraestrutura

Monorepo de infraestrutura Docker Swarm para os projetos justgu1.

## Domínios

| Domínio | Serviço | Stack |
|---|---|---|
| `hericarealtor.com` | App | `hericarealtor` |
| `justgui.dev` | App | `justgui` |
| `n8n.justgui.dev` | Automações | `automation` |
| `minio.justgui.dev` | MinIO S3 API | `storage` |
| `minio-console.justgui.dev` | MinIO Console | `storage` |
| `support.justgui.dev` | Chatwoot | `comms` |
| `evolution.justgui.dev` | Evolution API | `comms` |

## Estrutura

```
justgu1/
├── apps/                  ← gitignored — clone os repos aqui manualmente
├── infra/
│   └── core/
│       └── nginx/
│           ├── nginx.conf
│           └── conf.d/    ← um .conf por domínio
├── stacks/                ← Docker Stack files (Swarm)
│   ├── core.yml           ← Nginx + Certbot
│   ├── storage.yml        ← MinIO
│   ├── automation.yml     ← n8n
│   ├── comms.yml          ← Chatwoot + Evolution API
│   ├── hericarealtor.yml  ← Laravel Octane + PostgreSQL + Redis
│   └── justgui.yml        ← Go API + Astro
└── scripts/
    ├── bootstrap-vps.sh   ← passo 1: instala tudo na VPS
    ├── certbot-init.sh    ← passo 2: emite certificados SSL
    └── deploy-stack.sh    ← passo 3: sobe os stacks
```

## Redes overlay

| Rede | Uso |
|---|---|
| `proxy` | Nginx → todos os serviços expostos |
| `internal` | Comunicação interna (DBs, Redis, etc.) |

## Stacks e serviços

### `core` — Nginx + Certbot
- Nginx como reverse proxy centralizado (1 conf por domínio)
- Certbot com renovação automática a cada 12h

### `storage` — MinIO
- Buckets criados automaticamente: `hericarealtor`, `support`, `justgui`
- API: `minio.justgui.dev` | Console: `minio-console.justgui.dev`

### `automation` — n8n
- SMTP configurado via variáveis de ambiente

### `comms` — Chatwoot + Evolution API
- Chatwoot com PostgreSQL e Redis próprios
- Evolution API integrado ao MinIO e Redis do Chatwoot
- SMTP para e-mails transacionais

### `hericarealtor` — Laravel Octane
- Octane com Swoole (porta 8000)
- PostgreSQL + Redis próprios
- Queue worker separado
- APP_KEY gerado com `php artisan key:generate --show`

### `justgui` — Go API + Astro
- API Go na porta 8080 (`/api/*`)
- Frontend Astro na porta 4321

## Setup inicial na VPS

```bash
# 1. Bootstrap (Docker, Swarm, redes, clone do repo)
bash <(curl -fsSL https://raw.githubusercontent.com/justgu1/justgu1/main/scripts/bootstrap-vps.sh)

# 2. Preencher variáveis (copiar .env.example → .env e ajustar)
cp .env.example .env && nano .env

# 3. Emitir certificados SSL (DNS deve estar apontando para a VPS)
bash scripts/certbot-init.sh

# 4. Deploy de todos os stacks
bash scripts/deploy-stack.sh
```

## Deploy de stack individual

```bash
bash scripts/deploy-stack.sh core
bash scripts/deploy-stack.sh storage
bash scripts/deploy-stack.sh automation
bash scripts/deploy-stack.sh comms
bash scripts/deploy-stack.sh hericarealtor
bash scripts/deploy-stack.sh justgui
```

## Adicionar nova app

1. Adicionar entrada DNS apontando para a VPS
2. Criar `infra/core/nginx/conf.d/novoapp.conf`
3. Criar `stacks/novoapp.yml`
4. Adicionar domínio em `scripts/certbot-init.sh`
5. Adicionar URL vars em `.env`
6. Deploy: `bash scripts/deploy-stack.sh novoapp`

## Apps (repos externos)

```bash
# Clone manual em apps/ (pasta gitignored)
git clone git@github.com:justgu1/hericarealtor.git apps/hericarealtor
git clone git@github.com:justgu1/justgui.dev.git apps/justgui
```
