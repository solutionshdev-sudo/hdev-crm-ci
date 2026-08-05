# Estratégia

> O que importa agora. Prioridades, metas, prazos.
> O Claude usa isso pra decidir o que sugerir primeiro e o que adiar.
> Atualize sempre que as prioridades mudarem.

## Fase

Produto no ar (EasyPanel, 26/07/2026) — em processo de desvinculação total do
Chatwoot antes de abrir pra agências.

## Infra de desenvolvimento (28/07, revisada em 05/08)

> **MUDANÇA DE 05/08 — o CI saiu do repo privado.** O GitHub Actions da conta
> está bloqueado por falha de pagamento / spending limit, e a decisão do Harvey
> é **não pagar**. O CI passou a rodar num **espelho público só do código**
> (`solutionshdev-sudo/hdev-crm-ci`) — runner em repo público é grátis e
> ilimitado. O ciclo ganhou um passo manual: eu monto o commit de sync
> (allowlist de `hdevCRM/`, `baileys-service/`, `.github/` — nunca `_memoria/`)
> e **o push do espelho é do Harvey** (`git push --force ... HEAD:refs/heads/main`,
> que dispara o CI sozinho). Script: `scripts/sync-ci-mirror.sh`. Receita
> completa, armadilhas (bits de execução, branch default) e o incidente do push
> errado estão na memória `ci-espelho-publico-gratis` do Claude. Tudo abaixo
> sobre os jobs continua valendo — só o lugar onde rodam mudou.

**Existe CI**: `.github/workflows/ci.yml`, na raiz do repo. Quatro jobs — `rspec`,
`lint` (rubocop + eslint), `vitest` e `baileys` (desde 02/08, cobre o
microserviço: tsc + 29 testes vitest, node 22). Isso muda como o trabalho é planejado:
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

**Configuração já feita (30/07):** `TERMS_URL` e `PRIVACY_URL` apontam pra
`hdev.online/terms` e `/privacy` em produção. **Pendente: o rebuild** — até ele,
o código velho ainda roda o `.replace` contra o literal do chatwoot.com e ignora
as duas chaves, então o link visível continua o `/termos-de-uso` cravado na
tradução, que não existe.

**Feito (30/07, PR #7 mergeado em `5f4d3f9`):** Fase 6, as 7 constantes internas
Ruby (+220 refs; o namespace sozinho tinha 30, não 2 como a contagem inicial
dizia). Ficou em draft até o Deploy 1 (Fase 3b) ser confirmado no ar, para não
misturar rename de constante com mudança de front no mesmo deploy. **No ar e confirmada
em 30/07:** `HdevCrm.config[:version]` → `1.0.0` no container, ou seja o app
boota como `HdevCrm::Application`. Falta exercitar os caminhos que o boot não
cobre (login, conversa, `/super_admin`, e o log do worker atrás de `NameError`).
Duas armadilhas de grep, registradas em `_memoria/de-chatwoot.md`
porque valem além desta fase: `Chatwoot::` não casa `Chatwoot.`, e filtrar por
extensão esconde ERB dentro de YAML.

**Pendência de verificação (30/07):** os runs de CI dos merges do #6 e do #7 na
`main` foram **os dois cancelados** pelo push seguinte — é o
`cancel-in-progress` funcionando como projetado, mas significa que a `main` com
tudo junto só foi validada pelo run `30578790064` (disparado pelo commit de
contexto, que contém todo o código). **Conferir o desfecho dele na próxima
sessão** — cada PR passou verde isolado, mas a combinação nunca teve um run
completo confirmado. Vale sempre olhar o `conclusion`, não o código de saída:
`gh run watch --exit-status` devolve 0 até para run cancelado.

**Próximo (de-Chatwoot):** o que resta da Fase 6 **não é código, é coordenação
com o servidor** — `db:chatwoot_prepare` (5 chamadores; o `command` do compose
roda a task, então renomear e deployar junto vira restart loop: exige 2 deploys
com alias no meio), as 2 feature flags (migration obrigatória pro
`ACCOUNT_LEVEL_FEATURE_DEFAULTS`) e as chaves `CHATWOOT_*` (o
`CHATWOOT_INBOX_HMAC_KEY` assina os webhooks). Mais 2 decisões de janela:
`_chatwoot_session` (desloga todos os agentes) e o `channel_prefix` do
`cable.yml` (rompe assinaturas de ActionCable em voo).

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
(Lacuna **fechada em 04/08 pela Fase 3a do Motor Integrado** — ver a quarta
trilha abaixo: o agente de atendimento agora opera com tools escopadas na
conversa. O nó de IA do chatbot ainda usa `chat` puro; é a F3b.)

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

## Quarta trilha: Motor Integrado (01-05/08 — CINCO das seis fases na main: F1, F2, F3a, F3b, F4 e F5; F1/F4 provadas, o resto esperando a chave de IA e o deploy)

As peças existem mas não se conversam — o plano de 6 fases
(`~/.claude/plans/merry-mixing-toast.md`) liga kanban, chatbot, Baileys, IA e
automação num motor só: **P1** tudo vira evento no barramento; **P2** IA como
operadora (tools de escrita conversation-scoped); **P3** porta única de envio
com gates anti-ban; **P4** funil com semântica de venda. Ordem: F1 → (F2 anti-ban,
F4 kanban) → F3a/3b IA → F5 comercial → F6 disparo em massa (exige F2 provada).

**Feito (01/08, PR #25 mergeado em `712a9c5`):** Fase 1 — 7 eventos novos no
barramento (deal, chatbot flow, conexão WhatsApp), automação reagindo aos
eventos de deal, e o fix do `create_deal` no `validations.js` que destrava a
regra de fábrica do kanban (o bug conhecido desde 27/07). rspec verde de
primeira; armadilhas de CI registradas na memória do Claude. Ledger das fases
futuras em `.superpowers/sdd/merry-mixing-toast/progress.md`.

**Feito (02/08, PR #26 mergeado em `7e8ab69`):** Fase 2 — porta única de
envio + anti-ban. Coluna `contacts.automation_opted_out` (emenda: NÃO reusa
`blocked`, que é o mute global — contato que manda PARAR ainda consegue se
re-engajar), STOP detection (só texto digitado; botão "Cancelar" de menu não
bloqueia), `Messaging::SendGateService` (opt-out → janela 7h-22h fuso da
conta → warm-up por idade de pareamento → cap diário 300) com jitter de até
15min no postpone, e o baileys-service TESTADO pela primeira vez (19 vitest +
tsc, job `baileys` novo no CI). Veto adia ou registra com nota, nunca perde
mensagem em silêncio; retida/negada fica `failed`. **Deploy feito em 02/08 — número
conectado** (log: versão WA buscada em runtime funcionando + LID session OK;
2 erros benignos de JSON no backlog offline, upstream da lib Baileys, sem
crash). **Provas da F2 FECHADAS em 03/08** (§2.6.1-3): throttle provado local com
chip de teste (5 POSTs concorrentes → espaçamento mínimo 1.13s); PARAR
provado parcial em produção (nota de opt-out, automação retida como failed
+ nota, humano ainda envia, regex não casa frase, idempotente — e opt-out é
por contato: widget do site seguiu recebendo); janela provada forçando o
fuso da conta pra Hawaii (postpone automatizado é SILENCIOSO por design —
sem nota; a prova é `antiban_reschedule_count`=1 + chegada na abertura).
**Falta só a prova completa do PARAR (bot cala), que exige a chave de IA
(`ANTHROPIC_API_KEY` via InstallationConfig ou env) — é o último item do
gate da Fase 6.** Regra combinada: automatizável o Claude testa por script;
manual o Harvey executa com roteiro.

**Eco do celular RESOLVIDO (02-03/08, PRs #11 e #27 mergeados):** a análise
F2×eco não achou conflito de comportamento (helpers usam `messages_data`,
STOP guardado com `unless outgoing_echo`, eco não dispara gates); PR #11
mergeado, deployado nos 2 containers e **backfill provado em produção**
(snapshot de 4.951 mensagens → 8 dentro da janela de 24h entregues no
re-pareamento). O sintoma que a prova revelou — mensagens com horário de
"agora" e fora de ordem — virou o **PR #27**: `created_at` de mensagem
WhatsApp entrante agora vem do timestamp real do payload (futuro clampa em
agora) e o `default_scope` de `Message` desempata por `id` (created_at igual
era ordem arbitrária do Postgres). A caçada do PR #27 também matou um bug
latente de suíte: deletar chave DENTRO de `scan_each` do Redis pula chave
(rehash) — lock órfão de dedupe engolia mensagem em spec sem erro; os 5
cleanups migraram pra coleta-antes-de-deletar (memória
`rspec-redis-scan-delete-armadilha`). **Deploy do Rails feito e PROVADO em
03/08:** re-pareamento entregou o backfill com horário histórico real e em
ordem, e o eco apareceu ao vivo (mensagens enviadas por aparelho vinculado
entraram na conversa com timestamp são).

**Feito (03-04/08, PR #28 mergeado em `9309315`) — Fase 4 PROVADA:**
semântica de vendas no kanban. Deal não entra em etapa perdida sem
`lost_reason` (validação no model, só na entrada; modal no board no drag E
no form de edição); caminho programático preenche "Movido por automação"
(`ActionService` + `DealNode` — e a tool da F3a será o 3º call site, ver
memória `motor-fase4-mergeada`); lista de motivos por conta em
`account.settings.deal_lost_reasons`; `deal_pipelines.vocabulary` (jsonb,
rótulo nunca dado, editor só persiste chave editada — `lead`/`won` ainda
sem consumidor visual, wiring na F5); menu e título viraram "Kanban" fixo,
`vocabulary.deal` vive no botão "Novo {label}". Prova §4.4 integral em
produção 04/08 ("Novo Oportunidade" + título "Kanban" na mesma tela;
automação movendo pra Perdido sem quebrar).

**Feito (04/08, PR #29 mergeado em `229a87b`) — Fase 3a, código completo,
prova nível 4 pendente:** a IA deixou de só conversar e passou a **operar**.
Cinco tools de escrita conversation-scoped vivas em `SETS[:agent]`
(`MoverNegocioDaConversa`, `CriarNegocio`, `AtualizarContato`,
`EtiquetarConversa`, `TransferirParaHumano`), handoff barato por regex antes
do LLM (custo zero, sem `AiUsageEvent`) e o `AgentReplyService` rodando
`Ai::ToolLoop` em vez de `chat` puro. A segurança é arquitetural, não
textual: **nenhuma tool aceita id vindo do modelo** — o escopo vem do
`conversation`/`account` injetados, e um spec-allowlist recursivo quebra se
qualquer propriedade nova aparecer em qualquer schema do `:agent`. Duas
emendas ao plano: ligar o `AgentReplyService` ao `ToolLoop` entrou na fase
(sem isso nada consumiria o set) e `EtiquetarConversa` só aplica etiqueta já
cadastrada na conta (o `add_labels` grava tagging e não cria `Label`, então
etiqueta inventada por estranho nem aparecia no cadastro e furava a
validação de formato).

**Dois bugs de produção consertados de carona:** (1) o `default_scope` de
`Message` do PR #27 é ASC e `.order` só APPENDA — o `history_messages`
entregava a conversa **invertida** ao modelo desde 03/08; virou `reorder`,
com o mesmo conserto no `Chatbots::Nodes::AiNode`. (2) o PARAR da F2 não
valia pra escrita: o `enabled_for?` não olhava `automation_opted_out`, então
com as tools o contato que pediu PARAR teria dados reescritos sem receber
nada de volta. Contenções novas contra prompt injection: teto de 3 negócios
por conversa (o ciclo criar→perder→criar enchia o kanban da conta e
disparava `deal.won` no barramento) e truncagem do vocabulário da conta nos
erros de tool. Detalhes e armadilhas na memória `motor-fase3a-mergeada`.

**Feito (04/08, PR #30 mergeado em `f2e5b2d`) — Fase 3b:** a IA entrou no
fluxo e o dono IA ficou visível. O `Chatbots::Nodes::AiNode` roda `Ai::ToolLoop`
com as mesmas 5 tools da F3a (as duas portas de IA agora operam igual), com o
PARAR gateando ANTES do modelo e o handoff por tool saindo pelo handle certo
(decidido por `ToolLoop#executed`, não por reparse de texto). O review final
pegou o que faltava: o nó entregava as tools **sem o bloco de disciplina** do
system prompt da F3a — sem ele o nó reabria o vazamento de vocabulário interno
que a F3a tinha fechado; virou a constante compartilhada
`TOOL_DISCIPLINE_PROMPT`. Do lado visível: `Conversation#ai_handling?` no
payload e no presenter (badge vivo por websocket), filtro `conversation_type=ai`
num service próprio, badge "IA atendendo" na lista e no header, e aba "IA" que
abre em "Todos" (Minhas ∩ IA é vazia por construção). Pagou dívida junto:
`deal_node_spec` e `ai_node_spec` (primeira suíte `Chatbots::Nodes::*` do repo),
ator "Agente IA" nas activities de etiqueta (antes **nenhuma** activity nascia
nesse caminho) e o spec-guard automatizado de "nenhuma tool do `:agent` envia
mensagem".

**Feito (05/08, PR #31 mergeado em `33c0f1b`) — Fase 5, a camada comercial:**
a quota de IA deixou de ser número solto e passou a vir do plano —
`plan.ai_monthly_tokens` quando a assinatura está vigente (`active` ou
`past_due`), somado a `ai_extra_tokens`, com o fallback legado só quando não há
assinatura; **assinatura vigente manda sempre** (plano ilimitado não ressuscita
limite antigo — decisão travada por spec). Alarme por e-mail em 80% e 100% com
cooldown de 24h por limiar em Redis, dentro de rescue que nunca derruba a IA.
Suspensão de agência passou a propagar: conta filha e painel da agência levam
401 (`pending_payment` não propaga pras filhas, mas bloqueia o painel), e o
super admin ganhou `pending_payment` nos selects e motivo de suspensão editável
com o aviso do Stripe no hint nativo do administrate. E nasceu a **fonte de
captação**: `POST /public/api/v1/inboxes/:id/leads` (JSON e form), idempotente
por `external_id` no contato E na conversa, com telefone mascarado normalizado
(lead nunca se perde por máscara), throttle de 60/h por token e UI na tela da
inbox API com URL, snippet de `<form>` e botão de lead de teste. O card no
kanban nasce pela regra de fábrica da F1 — zero código de deal.

**Furo conhecido, primeiro item da F6:** a suspensão de agência **não alcança
superfície pública** — `PublicController` não passa pelo guard, então lead (e o
widget, que já era assim) de agência suspensa cria conversa, card e dispara os
listeners de IA: **agência suspensa continua gerando custo**.

**Próximo da trilha: F6 (disparo em massa), a última** — e ela tem
pré-requisito duro: o PARAR completo da §2.6.2. Junto dele seguem pendentes as
provas nível 4 da F3a (§3a.5), da F3b (§3b.4) e da F5 (§5.5, que ainda precisa
de SMTP) — as três primeiras dependem da mesma `ANTHROPIC_API_KEY` em produção.
Roteiro pronto em `.superpowers/sdd/merry-mixing-toast/roteiro-nivel4-f3a-f3b-parar.md`.

**Gate FECHADO (02/08) — Fase 1 provada em produção:** a regra de fábrica
salvou pela UI, o card nasceu sozinho ("Sistema criou o negócio" na atividade),
o funil foi exercitado até Ganho, e o log do worker mostrou o
`EventDispatcherJob` executando `deal.stage_changed` e `deal.won` com payload
GlobalID correto (~8ms, sem erro). F2 (anti-ban) e F4 (kanban) estão liberadas —
são independentes entre si. Minors observados na prova (não bloqueiam):
timestamp relativo do modal de atividades em inglês ("about 9 hours ago" —
date-fns sem locale pt-BR naquele componente, herdado) e o card auto-criado
nascendo com o display_id da conversa como título.

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

- ~~**Termos e privacidade não existem**~~ — **resolvidos em 30/07**. Estão no
  ar em `https://hdev.online/terms` e `https://hdev.online/privacy`, e as chaves
  `TERMS_URL`/`PRIVACY_URL` já apontam pra elas em produção (confirmado pelos
  dois caminhos: banco e `GlobalConfig.get`, que passa pelo cache do Redis).
  **As URLs não são as que a tradução de 27/07 tinha cravado** (`/termos-de-uso`
  e `/politica-de-privacidade`) — aqueles links estavam quebrados, e é por isso
  que virar configuração importou. Cada agência aponta pras dela pelo `Agency`.
  Como editar, porque não é óbvio: as duas nascem `locked: true` e **não
  aparecem** em `/super_admin/installation_configs`; só por `rails runner`. E
  `value` **não é coluna** — a tabela tem `serialized_value :jsonb` e `value` é
  acessor Ruby, então `update!(value:)` funciona mas `pluck(:value)` estoura
  `PG::UndefinedColumn`; usar `map`.
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
