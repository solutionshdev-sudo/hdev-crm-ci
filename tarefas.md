# Tarefas

> O que tá em jogo agora. O Claude lê e atualiza esse arquivo quando
> você pedir ("anota aí", "põe na lista", "o que tá pendente?").
> Formato livre — uma linha por tarefa, riscar ou remover quando concluir.

## Agora

- 🔴 **Erro 500 no `/super_admin`** — pegar o stack trace no log do container web
  antes de mexer em qualquer coisa (`docker logs <web> --since 15m | grep -A40 "Completed 500"`)
- Verificar se o resto da app (dashboard, conversas, widget) está OK ou se o 500 é geral
- Conferir amanhã se `INSTALLATION_NAME` continua "Hdev CRM" — prova de que o job de reversão morreu

## Em espera

- Fase 3: remover `enterprise/` e `spec/enterprise/`, deletar telemetria e banner de update (após 48h estável)
- Fase 3b: textos e links visíveis (precisa antes: publicar páginas de Termos e Privacidade próprias)
- Fase 5: rename da superfície do widget (`chatwootSDK`, classes `woot-`, cookies `cw_`)
- Fase 6: rename dos identificadores internos Ruby + `db:chatwoot_prepare` + feature flags
- DNS `crm.hdev.online` (registro A no Cloudflare, nuvem cinza) + domínio no EasyPanel
- SMTP (convites e recuperação de senha não funcionam sem isso)
- Rotina de backup diário do Postgres (cron no host)

## Concluídas recentes

- 2026-07-26 — Paleta verde completa + 30 favicons regerados + `/swagger` fechado (commit `5d1208e`)
- 2026-07-26 — `DISABLE_ENTERPRISE` ativo, marca restaurada no banco, alerta do Redis limpo
- 2026-07-26 — Instância acessível no ar (container web reimplantado + rota do domínio corrigida)
