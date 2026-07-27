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

**Feito (27/07):** super admin 100% limpo — widget de suporte/phone-home do
Chatwoot removido, versão própria 1.0.0 (não expõe mais a 4.16.0 do upstream),
cards EE com botões de upgrade removidos, links do Discord deles trocados por
contato@hdev.online, console todo em pt-BR (locale `administrate.pt_BR.yml`),
ícone de Agências e toggle claro/escuro.

**Próximo (de-Chatwoot):** remover a pasta `enterprise/` de vez, depois
textos/links visíveis, depois o rename do widget e dos identificadores internos.

## Segunda trilha: features de venda (27/07 — deployadas e validadas)

Entrega comitada e em produção: login do Super Admin no split-screen, pt-BR
100%, **WhatsApp não-oficial via microserviço Baileys próprio**
(`baileys-service/`, baileys `7.0.0-rc13` — o WhatsApp rejeitou a linha 6.x),
**construtor visual de chatbot** (@vue-flow, 12 nós) e **kanban de Negócios**.

**27/07:** diagnóstico completo das duas frentes (~30 achados) e conserto dos
críticos no commit `9d16269`: JID `@lid` era a causa do "conectou mas não
recebia" (Baileys 7 endereça chats por `@lid`; agora resolve pro número real) +
6 bugs quebra-tudo do chatbot (botões crashavam a sessão, delay nunca
retomava, roteamento de arestas, handoff). **WhatsApp validado ponta a ponta
em produção com chip real: recebe e envia.**

**Rodada 2 (plano aprovado, não implementado):** UX do Baileys pro cliente
final (mensagens de erro amigáveis — `code_515` é restart normal e assusta;
aba de reconexão nas configurações da inbox, que existe mas está inalcançável;
teardown com retry na exclusão; tela final sem QR wa.me), **regra de automação
de fábrica** pro kanban (hoje nenhum card nasce sozinho E um bug de validação
impede até salvar a regra à mão — `create_deal` fora do `noParamActions` do
`validations.js`) e rename "Negócios" → "Kanban". Plano em
`~/.claude/plans/snug-munching-peach.md`.

**Feito (27/07, sem commit):** polish UX do canvas do chatbot estilo Make —
duplo-clique abre config, drag threshold, snap-to-grid, arestas animadas,
busca na paleta, handles acessíveis (~30px) e fix do viewport inicial.
Pendente: commit + rebuild.

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
- `db/schema.rb` do repo desatualizado (parou em 2026_07_21, sem as tabelas de
  chatbot/kanban) — regenerar no container web e comitar.
- 2 instâncias zumbis do baileys no volume (`0ed2d284-…` e `685e21f5-…`, de
  canais deletados) ficam martelando registro no WhatsApp — limpar via
  `DELETE /instances/:id` (comandos na memória da sessão).
