# Tarefas

> O que tá em jogo agora. O Claude lê e atualiza esse arquivo quando
> você pedir ("anota aí", "põe na lista", "o que tá pendente?").
> Formato livre — uma linha por tarefa, riscar ou remover quando concluir.

## Agora

- 🔴 **Rodar o deploy com `b0e0ed5`** — o 1º build do redesign falhou no
  `assets:precompile` (SassCompressor × `rgb(var())`); o fix já está na `main`
- Depois do deploy: testar o console super admin **nos dois temas**, página a
  página (Painel, Contas, Agências, Usuários, Robôs, Apps, Configurações,
  forms de editar/criar, login) — dark tem que valer em tudo, sem string em inglês
- Comitar o polish UX do canvas do chatbot (estilo Make, 8 arquivos — feito
  27/07, ainda sem commit)
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

- 2026-07-27 — Redesign do console super admin comitado e pushed (`426385d` + fix do precompile `b0e0ed5`): dark global, tradução completa, switch de tema, visual do app
- 2026-07-27 — Rebuild do `161ee71` + telas de auth: deployado; 500 do `/super_admin` confirmado resolvido (console navegável em produção)
- 2026-07-26 — Paleta verde completa + 30 favicons regerados + `/swagger` fechado (commit `5d1208e`)
- 2026-07-26 — `DISABLE_ENTERPRISE` ativo, marca restaurada no banco, alerta do Redis limpo
- 2026-07-26 — Instância acessível no ar (container web reimplantado + rota do domínio corrigida)
