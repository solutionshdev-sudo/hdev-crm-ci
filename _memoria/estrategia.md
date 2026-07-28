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

**Resolvido (27/07):** o 500 do `/super_admin` (rota `index` de `agency_users`)
foi corrigido, deployado e confirmado — console navegável em produção.

**Feito (26/07, comitado em `2b34d7b`):** redesign split-screen das cinco telas
de auth e dois consertos de white-label no tema escuro. Falta rebuild
(o `DEFAULT_LOCALE=pt_BR` deixou de ser necessário — virou default no código
em 27/07).

**Feito (27/07):** super admin 100% limpo — widget de suporte/phone-home do
Chatwoot removido, versão própria 1.0.0 (não expõe mais a 4.16.0 do upstream),
cards EE com botões de upgrade removidos, links do Discord deles trocados por
contato@hdev.online, console todo em pt-BR (locale `administrate.pt_BR.yml`),
ícone de Agências e toggle claro/escuro.

**Feito (27/07, commits `426385d`+`b0e0ed5`):** redesign do console super admin
— dark mode em TODAS as páginas (SCSS do administrate tokenizado via pontes
`var(--sa-*)`; `rgb(var())` direto quebrava o SassCompressor do precompile),
tradução restante (`helpers.label`, "Novo(a) conta", filtros), switch compacto
de tema, visual alinhado ao app (tokens `n-*`, acento white-label) e azul
Chatwoot removido do gráfico do Painel. `PRODUCT.md` + `DESIGN.md` na raiz
viraram a fonte de verdade visual (skill Impeccable instalada com detector via
hook). **Pendente:** deploy com `b0e0ed5` + teste visual claro/escuro.

**Feito (27/07, commit `9617944`, pushado):** tradução pt-BR COMPLETA do app em 7 fases —
locale padrão da instância virou `pt_BR` no código (specs fixados em `:en`);
validações nativas do Rails e da política de senha em pt-BR
(`rails.pt_BR.yml`/`secure_password.pt_BR.yml`); erros do Super Admin agora em
flash VERMELHO (iam como notice verde); ~80 validações de models e ~140 erros
JSON da API extraídos pra I18n (`model_errors`/`api_errors` en+pt_BR, inglês
byte-idêntico pros specs); 20 subjects de e-mail via I18n + ~30 templates
traduzidos direto (Liquid não acessa I18n) incluindo o convite de agente
enterprise (é o que renderiza — view path prepended); installation_config.yml
(89 títulos) e features.yml (61 nomes) traduzidos; cauda do frontend Vue
fechada (preChat no idioma da conta, links de termos → hdev.online, {min} na
senha). Pendente: precompile+specs no Docker, teste visual.

**Próximo (de-Chatwoot):** remover a pasta `enterprise/` de vez, depois
textos/links visíveis (parte adiantada em 27/07: links de termos do signup e
remetente de e-mail já apontam pra hdev.online), depois o rename do widget e
dos identificadores internos.

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

**Rodada 2 (parcialmente implementada):** falta a UX de erro do Baileys pro
cliente final (mensagens amigáveis — `code_515` é restart normal e assusta;
teardown com retry na exclusão; tela final sem QR wa.me), a **regra de automação
de fábrica** pro kanban (hoje nenhum card nasce sozinho E um bug de validação
impede até salvar a regra à mão — `create_deal` fora do `noParamActions` do
`validations.js`) e o rename "Negócios" → "Kanban". Plano em
`~/.claude/plans/snug-munching-peach.md`.

**Feito (27/07, sem commit):** a parte de conexão da Rodada 2 — a inbox Baileys
agora mostra e reconecta a sessão **sem recriar a caixa de entrada**. Aba
própria "Conexão" (a `configuration`, gateada em `isAWhatsAppCloudChannel`,
mantinha o `<BaileysSession>` inalcançável), polling que não para ao conectar,
número pareado + última verificação, botão "Gerar novo QR code", selo de status
na lista de inboxes e banner acima do campo de resposta pro agente. No backend,
`connect!` reprovisiona antes de conectar e 404 do microserviço virou
`not_provisioned` — instância perdida em restart sem volume se auto-cura pelo
painel. Plano em `~/.claude/plans/aqui-no-painel-super-bright-hollerith.md`.
**Pendente:** deploy, teste com chip real (derrubar o container `baileys` e ver
o selo cair) e rodar os specs novos no container.

**Feito (27/07, commit `096daf3`):** polish UX do canvas do chatbot estilo Make —
duplo-clique abre config, drag threshold, snap-to-grid, arestas animadas,
busca na paleta, handles acessíveis (~30px) e fix do viewport inicial.
Pendente: rebuild.

## Terceira trilha: IA própria (substituta MIT do Captain)

O Captain (IA do Chatwoot) tem o miolo em `enterprise/` — licença que proíbe
revenda. Mas ~70% de uma IA própria já existia em código MIT: cliente Anthropic
com quota por conta/agência (`Ai::AnthropicService` + `Ai::QuotaService` +
`AiUsageEvent`), agente de atendimento com handoff e o motor de fluxo com 12
nós. A lacuna era uma só: **a IA só conversava, não agia** — faltava tool calling.

**Feito (27/07, commit `18e879b`, pushado):** fundação de tool calling.
`Ai::Tool` (schema em JSON Schema puro, neutro de provider), `Ai::ToolLoop`
(loop agêntico contra 4 seams, teto de 8 iterações, quota e `AiUsageEvent`
dentro do `raw_chat` que roda uma vez por iteração), `Ai::ToolRegistry`
(registry literal, `:agent` × `:copilot` como fronteira de segurança — o agente
roda em cima de mensagem de estranho e só pode receber leitura),
`Ai::Tools::CreateChatbotFlow` (gera fluxo como rascunho, o `FlowValidator` que
já existia é a rede de segurança), `DEFAULT_MODEL` de Opus 4.8 → Haiku 4.5
(US$1/5 vs US$5/25 por milhão de tokens) e as chaves Anthropic/OpenAI/Gemini no
super admin. **Nada foi executado** — sem Ruby nem Docker na máquina.

**Roadmap completo e decisões:** `~/.claude/plans/eu-quero-que-voce-glistening-noodle.md`.

**Decisões que não devem ser re-litigadas:**
- Loop manual único em vez do `tool_runner` do SDK: o helper exige tools como
  `Anthropic::BaseTool` com schema em `Anthropic::BaseModel` — DSL acoplada à
  Anthropic, incompatível com o schema único que o multi-provider precisa.
- Multi-provider (OpenAI/Gemini) **aprovado** — o que salvou `lib/llm/` da
  deleção: `Llm::Models.provider_for` vira o registry model→provider.
- Override de chave por agência **descartado**: `Agency#global_config_overrides`
  é hash hardcoded de branding, não store livre. O rateio é por quota.

**Próximo:** copiloto admin (item 5 — configurar CRM por linguagem natural com
preview do diff antes de aplicar), depois multi-provider, depois remover
`enterprise/`. RAG só quando um cliente reclamar que o bot não conhece o produto
dele — pgvector já está habilitado.

## O que pode esperar

- Definição da estrutura de planos de revenda pras agências (ainda em estudo).
- Reconstrução das features enterprise com código próprio (SLA, audit logs,
  custom roles, companies) — só depois da desvinculação terminar.
- Skills de marketing/conteúdo do template (carrossel, SEO, ads) — o foco
  agora é produto, não divulgação.

## Contexto com prazo

- Páginas `hdev.online/termos-de-uso` e `hdev.online/politica-de-privacidade`
  ainda não existem — o signup já aponta pra elas desde 27/07 (links do
  chatwoot.com removidos).
- Domínio `crm.hdev.online` sem DNS. Como `FRONTEND_URL` já aponta pra ele,
  links de e-mail saem quebrados até criar o registro A no Cloudflare.
- SMTP não configurado: convites de agente e recuperação de senha não saem.
- Backup do Postgres feito manualmente uma vez; falta a rotina de cron.
- `db/schema.rb` do repo desatualizado (parou em `2026_07_21_000003`, sem as
  tabelas de chatbot/kanban) — **9 migrations pendentes** nunca rodadas:
  `20260726120000` (única que escreve em dado existente: troca widgets do azul
  Chatwoot pro verde HDEV, e o `down` não reverte os registros) e
  `20260727000001..8` (tabelas de chatbot e deal, puramente aditivas). O deploy
  roda tudo sozinho (`db:chatwoot_prepare` → `db:migrate`, que está *enhanced*
  pra chamar o `ConfigLoader` logo depois), mas **fazer backup do Postgres
  antes**. Depois regenerar o `schema.rb` no container web e comitar — sem isso
  os specs de IA não rodam, porque carregam do schema.
- 2 instâncias zumbis do baileys no volume (`0ed2d284-…` e `685e21f5-…`, de
  canais deletados) ficam martelando registro no WhatsApp — limpar via
  `DELETE /instances/:id` (comandos na memória da sessão).
