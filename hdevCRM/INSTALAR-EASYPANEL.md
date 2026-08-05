# Instalar o Hdev CRM no EasyPanel

Guia pronto pra subir **este fork** (com o rebrand) no EasyPanel.

> ⚠️ **Regra de ouro:** este deploy builda a imagem a partir do código deste
> repositório (`docker/Dockerfile`). **Não** use a imagem oficial
> `chatwoot/chatwoot:latest` — se usar, o teu rebrand não aparece.

---

## Pré-requisito

O código precisa estar num repositório GitHub (o EasyPanel builda a partir dele).
Se ainda não subiu: rode `/salvar` no HDEV (repo **privado**).

---

## Opção A — Serviço "Compose" (mais rápido)

1. No EasyPanel: **Create Project** → `hdev-crm`.
2. Dentro do projeto: **Create Service → Compose**.
3. Aponte para o repositório GitHub e o arquivo **`docker-compose.easypanel.yaml`**.
4. Na aba **Environment**, cole o bloco de variáveis abaixo (já preenchido).
5. Deploy. No serviço **web**, aba **Domains**, adicione `crm.hdev.online`
   (porta 3000) — o EasyPanel emite o SSL automático.

---

## Opção B — 4 serviços pela UI (mais controle)

| # | Serviço | Tipo | Config |
|---|---------|------|--------|
| 1 | `postgres` | Postgres | Imagem `pgvector/pgvector:pg16` · DB `chatwoot` · senha abaixo |
| 2 | `redis` | Redis | senha abaixo |
| 3 | `web` | App | Source: GitHub · Build: Dockerfile `docker/Dockerfile` · Port 3000 · domínio |
| 4 | `worker` | App | mesmo build do `web` · sem domínio |
| 5 | `baileys` | App | Source: GitHub · Build Path `baileys-service/` · Port 3025 · **sem domínio** (só rede interna) |

- **web** → Command: `bundle exec rails s -p 3000 -b 0.0.0.0`
- **worker** → Command: `bundle exec sidekiq -C config/sidekiq.yml`
- Em `web` e `worker`, cole o mesmo bloco de Environment abaixo.
- Nos hostnames use o padrão do EasyPanel: `hdev-crm_postgres` e `hdev-crm_redis`
  (na Opção A/Compose, use só `postgres` e `redis`).

---

## Variáveis de ambiente (bloco pronto)

> 🔒 Trate isto como senha. Estes valores já foram gerados pra você.
> Se preferir, gere os seus: `openssl rand -hex 64` (secret) / `openssl rand -base64 18` (senhas).

```
RAILS_ENV=production
NODE_ENV=production
INSTALLATION_ENV=docker
RAILS_LOG_TO_STDOUT=true

SECRET_KEY_BASE=<ver local/easypanel-secrets.txt>
FRONTEND_URL=https://crm.hdev.online

POSTGRES_PASSWORD=<ver local/easypanel-secrets.txt>
REDIS_PASSWORD=<ver local/easypanel-secrets.txt>

ACTIVE_STORAGE_SERVICE=local
INSTALLATION_NAME=Hdev CRM
BRAND_NAME=Hdev CRM
MAILER_SENDER_EMAIL=Hdev CRM <sac@hdev.online>

# SMTP — preencha com teu provedor (ex: Zoho, Brevo, Amazon SES) pra e-mails saírem:
SMTP_ADDRESS=
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=

# Idioma padrão da instalação (telas de auth e contas novas)
DEFAULT_LOCALE=pt_BR

# WhatsApp não-oficial (baileys-service) — mesmo segredo usado pelo container baileys
# Gere com: openssl rand -hex 32
BAILEYS_API_KEY=<gerar hex de 32 bytes>
```

> Na **Opção B** você ainda precisa adicionar os hosts do banco/redis
> (o Compose já resolve isso sozinho):
> ```
> POSTGRES_HOST=hdev-crm_postgres
> POSTGRES_PORT=5432
> POSTGRES_USERNAME=postgres
> POSTGRES_DATABASE=chatwoot
> REDIS_URL=redis://:<REDIS_PASSWORD>@hdev-crm_redis:6379
> BAILEYS_URL=http://hdev-crm_baileys:3025
> RAILS_INTERNAL_URL=http://hdev-crm_web:3000
> DISABLE_ENTERPRISE=true
> ```
>
> `DISABLE_TELEMETRY` e `ENABLE_PUSH_RELAY_SERVER` não existem mais — a
> telemetria e o relay de push de terceiros foram removidos do código.
> Push pro app mobile agora exige credencial Firebase própria
> (`FIREBASE_PROJECT_ID` + `FIREBASE_CREDENTIALS` no super admin).
>
> Atenção: fora do Compose os defaults `http://baileys:3025` e o fallback
> pra `FRONTEND_URL` **não funcionam** — sem essas duas linhas o QR do
> WhatsApp não-oficial nunca aparece e o webhook sai pela internet pública.
> No serviço `baileys`, defina também `BAILEYS_API_KEY` (mesmo valor do
> `web`/`worker`), `PORT=3025` e `SESSIONS_DIR=/data/sessions` com um
> volume montado em `/data`.

---

## Migração do banco

- **Opção A (Compose):** já é automática — o serviço `web` roda
  `rails db:chatwoot_prepare` no primeiro boot.
- **Opção B (UI):** depois do 1º deploy do `web`, abra o **Console** do serviço e rode:
  ```
  bundle exec rails db:chatwoot_prepare
  ```

---

## Primeiro acesso

1. Abra `https://crm.hdev.online`.
2. Crie a conta de super admin (primeira tela de onboarding).
3. Vá em **Super Admin → Settings** e confirme:
   - `INSTALLATION_NAME` / `BRAND_NAME` = Hdev CRM
   - `MAILER_SUPPORT_EMAIL` = `sac@hdev.online`

---

## Checklist de erros comuns

- [ ] Imagem sendo **buildada** do `docker/Dockerfile` (não a oficial)
- [ ] Postgres é `pgvector/pgvector:pg16` (senão: erro `extension "vector"`)
- [ ] Migração rodou (senão: erro 500 no primeiro acesso)
- [ ] `FRONTEND_URL` = a URL real com `https://` (senão: links/e-mails quebrados)
- [ ] SMTP preenchido (senão: convites e recuperação de senha não saem)
