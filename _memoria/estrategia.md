# Estratégia

> O que importa agora. Prioridades, metas, prazos.
> O Claude usa isso pra decidir o que sugerir primeiro e o que adiar.
> Atualize sempre que as prioridades mudarem.

## Fase

Produto no ar (EasyPanel, 26/07/2026) — em processo de desvinculação total do
Chatwoot antes de abrir pra agências.

## Prioridade principal

**Desvincular o Hdev CRM do Chatwoot.** Status detalhado, decisões e armadilhas
em `_memoria/de-chatwoot.md` — ler antes de mexer no código.

Resumo: sair do modo enterprise (licença proíbe revenda), cortar telemetria,
remover toda menção ao Chatwoot (inclusive identificadores internos e a
superfície JS do widget) e completar a identidade visual verde.

**Feito (26/07):** paleta verde completa + favicons regerados + `/swagger`
fechado (commit `5d1208e`); kill-switch `DISABLE_ENTERPRISE` ativo em produção;
valores de marca restaurados no banco.

**Bloqueador agora:** erro 500 do `/super_admin` diagnosticado (rota `index`
inexistente de `agency_users` na sidebar), corrigido e publicado (commit
`161ee71`, já em `origin/main`) — falta o rebuild da imagem no EasyPanel pra
confirmar.

**Feito (26/07, comitado em `2b34d7b`):** redesign split-screen das cinco telas
de auth e dois consertos de white-label no tema escuro. Falta rebuild +
`DEFAULT_LOCALE=pt_BR` no EasyPanel.

**Próximo (de-Chatwoot):** remover a pasta `enterprise/` de vez, depois
textos/links visíveis, depois o rename do widget e dos identificadores internos.

## Segunda trilha: features de venda (27/07 — implementadas, não comitadas)

Entrega grande no working tree (~125 arquivos, plano aprovado): login do Super
Admin no mesmo split-screen, pt-BR 100% (0 chaves faltando), **WhatsApp
não-oficial via microserviço Baileys próprio** (`baileys-service/`, QR + proxy
por instância + disclaimers de risco), **construtor visual de chatbot**
(@vue-flow, 12 tipos de nó, motor próprio) e **kanban de Negócios** (Deal /
funil, com ações na automação). Estado detalhado e pendências em
`_memoria/analise-2026-07.md` e na memória da sessão.

**Pendente pra fechar a entrega:** commit (quebrar por fase), `db:migrate` +
rubocop/eslint num ambiente com Ruby, envs novas no EasyPanel
(`BAILEYS_API_KEY`, `DEFAULT_LOCALE=pt_BR`), rebuild da imagem, teste do
Baileys com chip descartável.

## O que pode esperar

- Definição da estrutura de planos de revenda pras agências (ainda em estudo).
- Reconstrução das features enterprise com código próprio (SLA, audit logs,
  custom roles, companies) — só depois da desvinculação terminar.
- Skills de marketing/conteúdo do template (carrossel, SEO, ads) — o foco
  agora é produto, não divulgação.

## Contexto com prazo

- Domínio `crm.hdev.online` sem DNS. Como `FRONTEND_URL` já aponta pra ele,
  links de e-mail saem quebrados até criar o registro A no Cloudflare.
- SMTP não configurado: convites de agente e recuperação de senha não saem.
- Backup do Postgres feito manualmente uma vez; falta a rotina de cron.
