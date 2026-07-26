# Tarefas

> O que tá em jogo agora. O Claude lê e atualiza esse arquivo quando
> você pedir ("anota aí", "põe na lista", "o que tá pendente?").
> Formato livre — uma linha por tarefa, riscar ou remover quando concluir.

## Agora

- 🔴 **Rebuild da imagem no EasyPanel** — destrava duas coisas de uma vez: o fix
  do 500 do `/super_admin` (commit `161ee71`, já no remoto) e as telas de auth
  novas. Restart não basta: o Dockerfile roda `assets:precompile` no build
- Depois do rebuild: abrir `/super_admin` e navegar por Accounts, Agencies, Users
  e Settings, pra garantir que não há outro recurso sem rota `index`
- Comitar o redesign das telas de auth (5 telas + `AuthSplitLayout.vue` + os dois
  consertos de white-label em `vueapp.html.erb` e `agency.rb`)
- Definir `DEFAULT_LOCALE=pt_BR` no EasyPanel — sem isso as telas de auth abrem
  em inglês mesmo com a tradução pronta
- Conferir se `INSTALLATION_NAME` continua "Hdev CRM" — prova de que o job de reversão morreu

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
