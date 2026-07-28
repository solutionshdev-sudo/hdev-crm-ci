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

**Feito (27/07, sem commit):** tradução pt-BR COMPLETA do app em 7 fases —
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
senha). Pendente: commit, precompile+specs no Docker, teste visual.

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

- Páginas `hdev.online/termos-de-uso` e `hdev.online/politica-de-privacidade`
  ainda não existem — o signup já aponta pra elas desde 27/07 (links do
  chatwoot.com removidos).
- Domínio `crm.hdev.online` sem DNS. Como `FRONTEND_URL` já aponta pra ele,
  links de e-mail saem quebrados até criar o registro A no Cloudflare.
- SMTP não configurado: convites de agente e recuperação de senha não saem.
- Backup do Postgres feito manualmente uma vez; falta a rotina de cron.
- `db/schema.rb` do repo desatualizado (parou em 2026_07_21, sem as tabelas de
  chatbot/kanban) — regenerar no container web e comitar.
- 2 instâncias zumbis do baileys no volume (`0ed2d284-…` e `685e21f5-…`, de
  canais deletados) ficam martelando registro no WhatsApp — limpar via
  `DELETE /instances/:id` (comandos na memória da sessão).
