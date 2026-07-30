# Estratégia

> O que importa agora. Prioridades, metas, prazos.
> O Claude usa isso pra decidir o que sugerir primeiro e o que adiar.
> Atualize sempre que as prioridades mudarem.

## Fase

Produto no ar (EasyPanel, 26/07/2026) — em processo de desvinculação total do
Chatwoot antes de abrir pra agências.

## Infra de desenvolvimento (28/07)

**Existe CI**: `.github/workflows/ci.yml`, na raiz do repo. Três jobs — `rspec`,
`lint` (rubocop + eslint) e `vitest`. Isso muda como o trabalho é planejado:
antes o código saía daqui sem nunca ter sido executado e a primeira verificação
era o deploy. Agora o Ruby é verificado antes, e o JS roda direto nesta máquina
(`corepack pnpm`). Detalhes de uso no `CLAUDE.md`.

O CI também é o que regenera o `db/schema.rb` — `db:migrate` em `RAILS_ENV=test`
redumpa o schema e publica como artifact, sem gastar janela de deploy.

**28/07 (noite): a suíte rspec executa de ponta a ponta pela primeira vez** —
18min19s, 8028 exemplos. O travamento crônico (90 min mudo até o timeout) era o
autoBuild do Vite dentro de spec de request num job sem Node; atrás dele, um OOM
de heap e o seed do ConfigLoader no banco de teste. Conserto no PR #1
(`ci/rspec-vite-autobuild-hang`), **mergeado na main (`f0fb6c6`) com CI 100%
verde** — `5994 examples, 0 failures`, rspec em ~15-16 min. Das 340 falhas:
239 eram `spec/enterprise` (excluído do run — Fase 3 deleta), ~100 eram o seed
do ConfigLoader, e só 2 sobreviveram — ambas spec desatualizado, **zero
regressões reais de código**. Detalhes operacionais no `CLAUDE.md` (seção CI);
mapa visual no Artifact "Anatomia das 340 falhas".

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

**Feito (28/07, Fase 5 antecipada):** rename da superfície JS do widget —
`chatwootSDK`→`hdevSDK`, `$chatwoot`→`$hdev`, `chatwootSettings`, os globais do
iframe, o prefixo postMessage, os eventos `chatwoot:*` e as chaves de
localStorage. 49 arquivos + 57 locales. O gatilho foi o snippet de instalação
(o que a agência cola no site do cliente dela) ainda dizer `window.chatwootSDK`.
Ficaram de fora por decisão: classes `woot-*` (617 refs) e cookies `cw_*` — não
soletram "chatwoot". Detalhes e armadilhas em `_memoria/de-chatwoot.md`.
**Pendente:** rebuild + teste manual em `/widget_tests` (o SDK não tem nenhum
teste unitário; o rename está verificado por grep, não por execução).

**Feito (29/07, PR #2 mergeado em `c4e3f74`):** Fase 3 — `enterprise/` e
`spec/enterprise/` deletados, 733 arquivos e −51.915 linhas, com a suíte
rodando **inteira** pela primeira vez (`5989 examples, 0 failures`).

**Feito (29/07, PR #3 mergeado em `59025f0`):** Fase 3-tele — `lib/chatwoot_hub.rb`
e toda a telemetria cortados (ping diário com contagens, registro da instância no
onboarding, relay de push, banner de update, changelog e testimonials). Nenhuma
linha do app fala com `hub.2.chatwoot.com`. As envs `DISABLE_TELEMETRY` e
`ENABLE_PUSH_RELAY_SERVER` viraram no-op e saíram do compose.

**Feito (30/07, PR #5 mergeado em `76eddb7`):** Fase 3b — textos e links
visíveis. **O bloqueio registrado aqui antes não existia:** `TERMS_URL` e
`PRIVACY_URL` são chaves de `installation_configs` e o
`Agency#global_config_overrides` já as sobrescreve **por agência** — o mecanismo
de cada revendedora apontar pros próprios termos sempre esteve pronto, e o Help
Center do produto (`/hc/:slug/:locale/articles/:slug`, MIT, público) hospeda sem
uma linha de código. Não depende do hdev.online.

O que a fase achou foi um bug de white-label **nosso**: o `Form.vue` aplicava a
config por `.replace` de string literal, e a tradução pt-BR de 27/07 cravou
`hdev.online` no texto de `en` e `pt_BR` — o replace parou de casar e o
`TERMS_URL` virou no-op nos dois locales que usamos, então toda agência
revendedora exibia os termos da HDEV no próprio cadastro. Agora é interpolação
do vue-i18n nos 57 locales, com spec que falha se algum voltar a cravar URL.
Saiu junto a cadeia `feature_help_urls` → `window.globalConfig.helpUrls` (que
publicava as URLs de documentação do Chatwoot em toda página e não tinha
consumidor no frontend) e os fallbacks de remetente `accounts@chatwoot.com`.

**Pendente, e é o que segura o resultado prático:** criar os dois artigos no
Help Center e apontar `TERMS_URL`/`PRIVACY_URL` pra eles. Enquanto valerem `'#'`,
o link do cadastro não leva a lugar nenhum — o conserto garante que ele *obedece*
à configuração, não que a configuração exista.

**Próximo (de-Chatwoot):** sobra a **Fase 6** (identificadores internos Ruby),
com auditoria feita em 30/07 — ver `_memoria/de-chatwoot.md`.

**Dois azuis que sobraram, achados em 28/07 (não corrigidos):**
- `app/javascript/.../inbox/channels/Website.vue:21` — `channelWidgetColor: '#009CE0'`
  cravado no estado do componente e sempre enviado no payload, então **inbox de
  site criada pela UI nasce azul**, ignorando o default verde da coluna. Não é o
  `#1f93ff` que a migration caçava; é outro azul do Chatwoot.
- `app/models/label.rb:6` e `app/services/ai/tools/create_labels.rb:57` —
  etiqueta nova nasce `#1f93ff`.

## Segunda trilha: features de venda (27/07 — deployadas e validadas)

Entrega comitada e em produção: login do Super Admin no split-screen, pt-BR
100%, **WhatsApp não-oficial via microserviço Baileys próprio**
(`baileys-service/`, baileys `7.0.0-rc13` — a versão do cliente WhatsApp Web
**não** é mais fixada, ver o conserto de 29/07),
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

**Feito (27/07, commit `38ec4fd`):** a parte de conexão da Rodada 2 — a inbox Baileys
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

**Conserto (28/07):** a feature acima não entregava o que prometia. O `#status`
do `BaileysSessionService` — que o polling da aba Conexão chama a cada 3-15s —
**nunca persistia** o `connection_state`; só o webhook e o `logout!` gravavam.
Consequência: o selo da lista de inboxes e o banner da caixa de resposta ficavam
no último valor visto pelo webhook — verde para sempre numa inbox cuja instância
morreu. Agora o polling sincroniza, escrevendo só quando o estado muda. Junto:
tooltip da lista usa `STATUS_SINCE` (o campo é quando o estado *mudou*, não
quando foi lido), refetch de inboxes com freio de 30s e o comentário do
`MAX_POLL_FAILURES` corrigido (~75s em repouso, não ~15s). **O teste que
importa** é derrubar a sessão pelo celular e conferir que o selo da *lista*
também fica vermelho.

**Conserto (28/07, nº 2):** a aba Conexão travava a **página inteira** em
"carregando" — e só quando a sessão estava conectada, que é por isso que passou
batido. Ciclo fechado entre três arquivos: o `BaileysSession` emitia `connected`
já na primeira leitura, o `Settings.vue` respondia com `dispatch('inboxes/get')`,
o `uiFlags.isFetching` trocava a **raiz** do template pelo spinner, o componente
desmontava, remontava com o `status` zerado — e a primeira leitura acontecia de
novo. Duas XHRs por volta, para sempre. Correção: `status` nasce `null` (que não
é o mesmo que `'disconnected'`) e o emit exige uma transição observada dentro da
mesma montagem. Deixou spec de regressão em vitest, verificada revertendo o guard.
**Lição que vale além daqui:** emitir evento no `onMounted` é seguro só enquanto
o pai não puder desmontar o filho em resposta — e `uiFlags` global de fetch na
raiz de um template faz exatamente isso.

Junto, no microserviço: `loadAll` só reconecta instância com credencial pareada.
O teste é `creds.registered`, **não** a existência do `creds.json` — o
`useMultiFileAuthState` grava esse arquivo já na primeira tentativa de registro,
com `registered: false`, então existir não prova nada. É o que o comentário da
função já prometia e o código não fazia, e era o que mantinha as instâncias
zumbis gerando QR eterno no mesmo event loop single-thread das instâncias boas.
**Pendente:** deploy (o frontend precisa de rebuild). As 3 zumbis já foram
apagadas do volume em 28/07.

**Conserto (29/07, branch `fix/baileys-wa-version`, commit `16e5480` pushado):**
o WhatsApp caiu de novo — `code_405` no painel e reconexão de 60 em 60 segundos
a noite toda, sem nunca emitir QR. **A causa não era a sessão:** depois de
apagar a auth state, o registro novo levava o mesmo 405. É a **versão do cliente
WhatsApp Web que o Baileys hardcoda**: a rc13 pede `2.3000.1035194821` e o
WhatsApp já exige `2.3000.1044104838`. Provado em A/B na mesma máquina, um atrás
do outro — versão velha → `CLOSE statusCode=405`, versão nova → QR em 2s.

**A lição, que é a parte que vale:** esse é o mesmo bug do `5af436b`, que
"resolveu" subindo 6.x → rc13 e durou dois meses. **Fixar a versão É o bug** —
subir pra rc14 compraria mais um mês. Agora a versão se pergunta ao WhatsApp no
`connect()` (`fetchLatestWaWebVersion`, timeout de 5s, fallback pra última boa
da réplica). Quando o WhatsApp bumpar de novo, não tem nada a fazer.

Dois consertos que o 405 escancarou, na mesma leva:
- **405, 403 e 411 agora são fechamentos fatais** ao lado do 401: apagam a auth
  state e param. Sem isso o serviço martelava o WhatsApp para sempre com
  credencial morta (risco de ban de número não-oficial) e o painel ficava em
  "Conectando…" eterno — o Baileys **só emite QR quando `creds.registered` é
  false**, então credencial morta no disco é um beco sem saída pelo painel.
  Códigos transitórios (428, 408, 515) mantêm o backoff.
- `teardownSocket()` roda antes do `removeAuthState()` e também remove o
  listener de `creds.update`: o socket morto reescrevia o `creds.json` em cima
  do diretório recém-apagado.

**Pendente:** rebuild **do container `baileys`** (é imagem própria, o rebuild do
app não cobre) e **repareamento do número** — a auth state do
`+5516997223968` foi apagada no diagnóstico, a inbox está desconectada.

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

**Feito (28/07, commits `0bb5c2c`+`e90bcd1`):** o copiloto admin (item 5).
`POST /copilot` roda o `ToolLoop` com savepoint por chamada — as ferramentas
rodam de verdade e o banco é desfeito, então a validação do preview é a real e
nenhuma tool precisa saber que está em preview. `POST /copilot/apply` reexecuta
os changes numa transação única (tudo ou nada), sem passar pelo modelo de novo.
Quatro tools novas no `SETS[:copilot]`: `criar_funil`, `criar_etiquetas`,
`definir_horario_atendimento`, `vincular_chatbot_a_inbox`. Modelo `claude-opus-5`
(thinking ligado por padrão divide o `max_tokens` com a resposta — daí o teto de
8192). Tela em Configurações → Copiloto, com `meta.permissions: administrator`.

**Decisão que mudou na implementação:** não há componente de renderização de
diff. O backend já devolve `result` como frase pronta em português
(`Funil "X" com as etapas: A → B → C.`), então o preview é uma `<ul>` de strings
— e o próprio preview é a confirmação, sem modal, porque o backend garante que
nada foi gravado. **Deployado em 28/07** — o item "Copiloto" já aparece no menu
de Configurações. **Pendente:** o teste ponta a ponta (é o único ponto que valida
o id do modelo — os specs stubam o `Ai::AnthropicService` inteiro).

**Próximo:** multi-provider (o `enterprise/` já saiu em 29/07). RAG só quando um
cliente reclamar que o bot não conhece o produto dele — pgvector já está
habilitado.

## O que pode esperar

- Definição da estrutura de planos de revenda pras agências (ainda em estudo).
- **Reconstrução das features enterprise: virou lista de espera com gatilho por
  pedido de cliente, não roadmap** (decisão de 29/07). Há zero agências pagantes
  hoje e cada uma é código a manter sem demanda. **Companies foi cortada de vez**
  — o Kanban de Negócios cobre o caso, e um atributo customizado "empresa" no
  contato resolve o resto. Audit logs volta primeiro se alguém pedir compliance
  (~70 linhas, a gem `audited` faz o trabalho); custom roles e SLA ficam adiados,
  o primeiro porque o custo real é a matriz de permissões em ~20 policies e o
  segundo porque são ~600 linhas e 3 tabelas. Voz idem, e é a mais cara de todas
  (WebRTC + gravação + consentimento LGPD).
- **Já reconstruída (29/07, PR #4):** transcrição de áudio. Não estava naquela
  lista e vale mais que as quatro — áudio no WhatsApp é expectativa no Brasil.
  Saiu barata porque o contrato inteiro era MIT e já estava no core: faltava só
  quem preenche o `meta['transcribed_text']`.
- Ainda de pé como candidata barata: os **campos de limite/feature do super
  admin** (~20 linhas de `Administrate::Field`) — é a UI que liga feature e seta
  limite por conta, ou seja, a mecânica dos planos de revenda.
- Skills de marketing/conteúdo do template (carrossel, SEO, ads) — o foco
  agora é produto, não divulgação.

## Contexto com prazo

- **Termos e privacidade ainda não existem em lugar nenhum.** Desde 30/07 isso
  não depende mais do hdev.online: o signup lê `TERMS_URL`/`PRIVACY_URL` de
  `installation_configs` (hoje `'#'`), e o Help Center do próprio produto
  hospeda em `crm.hdev.online/hc/<slug>/pt-BR/articles/<slug>` sem código novo.
  Falta escrever os dois textos, publicar como artigos e setar as duas chaves.
  Cada agência pode apontar pras dela pelo `Agency` — o override já funciona.
- ~~Domínio `crm.hdev.online` sem DNS~~ — **resolvido em 28/07**. Responde 200
  servindo o app, atrás do Cloudflare. Como `FRONTEND_URL` já apontava pra ele,
  os links de e-mail deixaram de sair quebrados (falta o SMTP pra testar).
- SMTP não configurado: convites de agente e recuperação de senha não saem.
- Backup do Postgres feito manualmente uma vez; falta a rotina de cron.
- ~~9 migrations pendentes em produção~~ — **aplicadas em 28/07**. Confirmado no
  container: `needs_migration?` → `false` e as 8 tabelas de chatbot/deal existem.
  O `db/schema.rb` já tinha sido regenerado pelo CI e commitado
  (`2026_07_21_000003` → `2026_07_27_000008`) — era o que travava a suíte, porque
  `maintain_test_schema!` dá `exit 1` com migration pendente.
  **Detalhe que a verificação revelou:** `Channel::WebWidget.group(:widget_color).count`
  voltou `{}` — não existia **nenhum** widget no banco, então o backfill da
  `20260726120000` não tocou em linha alguma. É o que autorizou o rename da
  superfície JS sem retrocompatibilidade (nada instalado pra quebrar).
- ~~3 instâncias zumbis do baileys no volume~~ — **apagadas em 28/07**. Eram
  três, não duas (`0ed2d284-…`, `5716d36c-…` e `685e21f5-…`, de canais
  deletados), e ficavam martelando registro no WhatsApp. Fica o método, porque
  vai acontecer de novo: a instância viva do `+5516997223968` é a
  `2d3f0585-…` — **não** a `5716d36c-…`, como uma anotação anterior dizia.
  Causa confirmada em 28/07:
  `teardown_baileys_instance` faz `rescue StandardError` e só loga, então
  microserviço fora do ar na hora de apagar a inbox = diretório de sessão órfão
  pra sempre. Como identificar: no log do baileys elas levam 401 no webhook
  enquanto a instância viva passa; o motivo sai no log do Rails
  (`no channel for instance=` → órfã de verdade; `invalid signature` → é
  `webhook_secret` divergente, e aí o remédio é reprovisionar, não apagar).
  Conferir antes de apagar — o `DELETE` some com a sessão. O guard novo no
  `loadAll` evita a recorrência do sintoma (QR eterno), mas não a órfã em si.
