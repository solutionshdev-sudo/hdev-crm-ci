# Análise completa do projeto — julho/2026

> Gerada na rodada de 2026-07-26/27. Cobre auditoria de auth, i18n,
> canais/automação e os fixes aplicados. Complementa `de-chatwoot.md`
> (que continua sendo o documento de verdade da migração).

## Estado geral

Fork do Chatwoot 4.16 (Rails 7.1 / Ruby 3.4 / Vue 3 + Vite). Rebrand visual
concluído (paleta verde, favicons, auth split-screen). Enterprise desligado por
env; remoção física aguarda gate de 48h. O código está saudável — os problemas
encontrados são de acabamento, não estruturais.

## Aplicado nesta rodada (baixo risco)

| Item | Arquivo(s) |
|---|---|
| Login do Super Admin redesenhado (split-screen igual ao login normal, i18n en/pt-BR, dark mode consertado — nada aplicava `.dark` no pack superadmin) | `app/views/super_admin/devise/sessions/new.html.erb`, `scss/super_admin/index.scss` (tokens `--blue-*` + `.auth-brand`), `layouts/super_admin/application.html.erb`, `en.yml`/`pt_BR.yml` |
| pt-BR 100% (0 chaves faltando nas 6.092): `calls.json` criado, `CAPTAIN_GENERATION` (12), `SIDEBAR.CALLS`, menu slash do editor, helpCenter | `dashboard/i18n/locale/pt_BR/*` |
| `pt_BR/index.js` convergido com `en/index.js` (+calls, −webhooks morto) | idem |
| `fallbackLocale: 'en'` nos 3 entrypoints que não tinham (chave faltante nunca mais vira key-path na tela) | `entrypoints/{dashboard,widget,survey}.js` |
| Vazamento `app.chatwoot.com` no helpCenter (4 ocorrências en+pt_BR) → domínio neutro | `en/helpCenter.json`, `pt_BR/helpCenter.json` |
| `errors.account.support_email.invalid` traduzido | `config/locales/pt_BR.yml` |
| `DEFAULT_LOCALE=pt_BR` ativado no `.env.example` (produção: setar no EasyPanel) | `.env.example` |
| `isACustomBrandedInstance`/`isAChatwootInstance` viraram constantes (comparavam com a string `'Chatwoot'`, que nunca mais casa) | `shared/store/globalConfig.js` |
| `LOGIN.TITLE` órfão removido de en/pt_BR (não usado desde `2b34d7b`) | `locale/{en,pt_BR}/login.json` |
| Contrato do provider WhatsApp alinhado: base declarava `validate_provider_config` sem `?`, filhos implementam com `?` | `whatsapp/providers/base_service.rb` |
| `pt_BR.iso_639_3_code` preenchido (`por`) — metadado; confirmado não consumido no código | `config/initializers/languages.rb` |

**Falso positivo descartado:** a suspeita de caracteres corrompidos no
`en/inboxMgmt.json` era encoding do console na inspeção — o arquivo é UTF-8
válido (0 × U+FFFD).

## Backlog priorizado (não aplicado nesta rodada)

### Urgente — infra (bloqueia operação real)
1. **SMTP não configurado** — convite de agente e reset de senha não saem.
2. ~~**DNS `crm.hdev.online` não existe**~~ — **resolvido em 28/07**: responde 200 atrás do Cloudflare.
3. **Backup do Postgres sem rotina** — só foi feito manual uma vez.

### Alto — de-Chatwoot (gates próprios, ver `de-chatwoot.md`)
4. Fase 3: remover `enterprise/` + telemetria (`chatwoot_hub`) após 48h estável.
5. Fase 3b: Termos/Privacidade próprios. Atenção ao mecanismo frágil do
   `signup.json TERMS_ACCEPT`: o Vue substitui a URL `chatwoot.com` **por match
   de string exata** (`Form.vue:56`) — não editar o JSON sem trocar o mecanismo.
6. `LOGIN.TITLE` com "Chatwoot" segue nos ~50 locales não-mantidos (chave órfã,
   ninguém renderiza — sai junto com a limpeza de locales).

### Médio — higiene
7. **15 pastas de locale órfãs** no dashboard (`am az bn hr hy ka ms ne sh sl sq tl ur ur_IN zh`)
   não são importadas pelo `i18n/index.js` — remover ou passar a importar (recomendo remover).
8. `webhooks.json` (en+pt_BR) morto — `WEBHOOKS_SETTINGS` não é referenciado.
9. `crowdin.yml` usa `%two_letters_code%` — pt_BR fica fora do pipeline de
   tradução; irrelevante enquanto a tradução for manual, mas documentado.
10. WARN `Session activity update failed` no login do Super Admin — log
    melhorado já em produção; decidir `skip_after_action` após o próximo rebuild
    (diagnóstico em `de-chatwoot.md`).
11. Painel interno do Administrate em inglês — custo alto (override de todos os
    `app/dashboards/*`), benefício baixo (só o Harvey usa). Adiado de propósito.

### Produto — em execução (plano aprovado, fases 4–8)
12. WhatsApp não-oficial via microserviço Baileys próprio (proxy por instância,
    avisos de risco obrigatórios na UI).
13. Construtor visual de chatbot (canvas `@vue-flow/core` + motor próprio).
14. Kanban de Negócios (Deal/Pipeline/Stage) com ações de automação.
