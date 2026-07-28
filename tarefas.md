# Tarefas

> O que tá em jogo agora. O Claude lê e atualiza esse arquivo quando
> você pedir ("anota aí", "põe na lista", "o que tá pendente?").
> Formato livre — uma linha por tarefa, riscar ou remover quando concluir.

## Agora

- 🔴 **Rebuild da imagem** pro rename da superfície do widget (Fase 5, 28/07) —
  restart não basta, o `assets:precompile` só roda no build. Depois: abrir
  `/widget_tests`, conferir `hdev:ready` no console e a bolha **abrir E fechar**
  (se abrir e ficar inerte, o prefixo postMessage dessincronizou)
- ~~Rodar o deploy com `b0e0ed5`~~ — feito em 28/07 (as 9 migrations rodaram,
  `needs_migration?` → `false`, e o menu Copiloto apareceu)
- Depois do deploy: testar o console super admin **nos dois temas**, página a
  página (Painel, Contas, Agências, Usuários, Robôs, Apps, Configurações,
  forms de editar/criar, login) — dark tem que valer em tudo, sem string em inglês
- Depois do deploy: testar a aba **Conexão** da inbox WhatsApp — derrubar o
  container `baileys` e ver o selo cair (lista, aba e banner na conversa), e
  clicar em "Gerar QR code" com a instância fora da memória pra confirmar a
  auto-provisão
- Rodar no container os specs novos do Baileys (`baileys_session_service_spec`,
  `baileys_controller_spec`) + `vitest` do helper — nada foi executado aqui
- ~~Definir `DEFAULT_LOCALE=pt_BR` no EasyPanel~~ — desnecessário desde 27/07,
  `pt_BR` virou o default no código (`application.rb`); o painel abriu em
  português em 28/07, confirmado
- Conferir se `INSTALLATION_NAME` continua "Hdev CRM" — prova de que o job de reversão morreu

## Em espera

- Fase 3: remover `enterprise/` e `spec/enterprise/`, deletar telemetria e banner de update (após 48h estável)
- Fase 3b: textos e links visíveis (precisa antes: publicar páginas de Termos e Privacidade próprias)
- ~~Fase 5: rename da superfície do widget~~ — **feita em 28/07** (globais, eventos,
  postMessage, localStorage). Classes `woot-` e cookies `cw_` ficaram de fora por
  decisão: não soletram "chatwoot". Falta rebuild + teste em `/widget_tests`
- Fase 6: rename dos identificadores internos Ruby + `db:chatwoot_prepare` + feature flags
  (inclui `window.chatwootConfig`, global do dashboard que a Fase 5 não tocou)
- Corrigir os dois azuis remanescentes: `Website.vue:21` (`#009CE0`, inbox de site
  nasce azul) e o default de `Label` (`#1f93ff`)
- DNS `crm.hdev.online` (registro A no Cloudflare, nuvem cinza) + domínio no EasyPanel
- SMTP (convites e recuperação de senha não funcionam sem isso)
- Rotina de backup diário do Postgres (cron no host)

## Concluídas recentes

- 2026-07-27 — Aba **Conexão** na inbox WhatsApp: status ao vivo, número pareado, QR de reconexão sem recriar a caixa, selo na lista e banner na conversa; backend reprovisiona sozinho a instância perdida
- 2026-07-27 — IA própria (tool calling, substituta MIT do Captain) comitada e pushed (`18e879b`)
- 2026-07-27 — Tradução pt-BR completa do app comitada e pushed (`9617944`)
- 2026-07-27 — Polish UX do canvas do chatbot comitado (`096daf3`)
- 2026-07-27 — Redesign do console super admin comitado e pushed (`426385d` + fix do precompile `b0e0ed5`): dark global, tradução completa, switch de tema, visual do app
- 2026-07-27 — Rebuild do `161ee71` + telas de auth: deployado; 500 do `/super_admin` confirmado resolvido (console navegável em produção)
- 2026-07-26 — Paleta verde completa + 30 favicons regerados + `/swagger` fechado (commit `5d1208e`)
- 2026-07-26 — `DISABLE_ENTERPRISE` ativo, marca restaurada no banco, alerta do Redis limpo
- 2026-07-26 — Instância acessível no ar (container web reimplantado + rota do domínio corrigida)
