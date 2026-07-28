# Projeto: desvincular o Hdev CRM do Chatwoot

> Documento de trabalho da migração. Atualizar ao fim de cada fase.
> Última atualização: **2026-07-27**

---

## Por que esse projeto existe

O Hdev CRM é um fork do Chatwoot 4.16.0 vendido como white-label para agências.
Três problemas impediam isso de funcionar:

1. **Um job diário desfazia o rebrand.** A extensão enterprise do
   `CheckNewVersionsJob` chama `ReconcilePlanConfigService`, que ao detectar plano
   "community" reescrevia no banco `INSTALLATION_NAME` → "Chatwoot", logos,
   `BRAND_URL`/`TERMS_URL`/`PRIVACY_URL` → chatwoot.com, `DISPLAY_MANIFEST` → true,
   e desabilitava `disable_branding` em todas as contas. Era a origem do banner
   "An update 4.16.1 is available" que aparecia no dashboard.
2. **A instância conversava com a infraestrutura do Chatwoot**: ping diário com
   contagem de contas/usuários/conversas, relay de push mobile, widget de suporte
   no Super Admin, e `/swagger` público anunciando "Chatwoot".
3. **A marca estava pela metade**: logos verdes, UI azul, favicons do Chatwoot.

## A questão de licença (define tudo)

- **`hdevCRM/LICENSE`** — o núcleo é **MIT**. Pode modificar, sublicenciar e
  **vender**. Rebrandar e revender para agências é legítimo; basta manter o aviso
  de copyright (nunca alterar o arquivo `LICENSE`).
- **`hdevCRM/enterprise/LICENSE`** — o conteúdo dessa pasta *"may only be used in
  production [with] a valid Chatwoot Enterprise License"* e *"it is forbidden to
  copy, merge, publish, distribute, sublicense, and/or sell the Software"*.
  Ou seja: **usar em produção sem assinatura, e revender, viola a licença.**
- **O app entra em modo enterprise só pela presença da pasta `enterprise/`**
  (`lib/chatwoot_app.rb:14-18`). Não há chave de licença nem verificação
  criptográfica — o "plano" é uma string em `installation_configs`.
  Remover a pasta resolve a exposição jurídica **e** mata o job de reversão.

**Decisão tomada:** sair do modo enterprise, e reconstruir depois com código
próprio (MIT, vendável) as features que importarem — prioridade: **SLA**,
**audit logs**, **custom roles**, **companies** (as tabelas continuam existindo,
pois as migrations são do core MIT).

**Ganho já obtido:** `disable_branding` — que remove o "Powered by" do widget,
portal e rodapé de e-mail — é implementado no core MIT. Só o serviço enterprise
o desligava diariamente. Agora pode ser ligado por conta e permanece.

## Outras decisões aprovadas

| Tema | Decisão |
|---|---|
| Profundidade do rename | **Tudo**, inclusive identificadores internos Ruby e a superfície JS do widget, **sem retrocompatibilidade** (não há widget instalado em cliente ainda) |
| Updates do upstream | **Não** vamos puxar. O fork segue vida própria — libera renames agressivos, mas a manutenção de segurança passa a ser nossa |
| Cor de acento | Verde `#00D488` do logo. Sólido de CTA: `#00875A` |

---

## Onde paramos (2026-07-26)

### ✅ Concluído

**Fase 1 (código) e Fase 4 completas** — commit `5d1208e`, já em `main` no GitHub:
- `/swagger` deixou de ser servido em produção (era público, sem autenticação)
- Paleta verde aplicada: tokens `--blue-1..12` claro/escuro, `brand` do Tailwind,
  paleta legada `woot-*`, e-mails, `manifest.json`, flash do launcher do widget,
  administrate, e todos os hex azuis remanescentes
- 30 favicons/ícones PWA regerados (tile `#0F172A` + chevrons `#00FF9F`)
- Migration `20260726120000` — default de `widget_color` → `#00875A` + backfill
- `identidade/design-guide.md` preenchido com a paleta oficial

**Fase 1 (servidor) e Fase 2 executadas pelo Harvey no EasyPanel:**
- Env vars `DISABLE_ENTERPRISE=true`, `ENABLE_PUSH_RELAY_SERVER=false`,
  `DISABLE_TELEMETRY=true` adicionadas e implantadas
- Os 10 valores de marca restaurados no banco (saída confirmou `OK` para todos)
- Chave Redis do alerta (`CHATWOOT_CONFIG_RESET_WARNING`) limpa

### 🟡 Telas de auth redesenhadas — comitadas (`2b34d7b`), falta deployar

As cinco telas de auth (login, SSO/SAML, esqueci a senha, redefinir senha,
verificar e-mail) saíram do card centralizado herdado do Chatwoot e passaram a
usar um layout split-screen próprio: `app/javascript/v3/components/Auth/AuthSplitLayout.vue`
(painel escuro com brilho radial em CSS, logo, headline e rodapé; formulário à
direita). Textos novos em `en/login.json` e `pt_BR/login.json`.

A segunda linha da headline é o `globalConfig.installationName` em runtime, não
uma string traduzida — cada agência vê o próprio nome sem tradução nova, e nada
no texto cita "Hdev CRM" (o `LOGIN.TITLE` antigo citava, e o `useBranding` só
substitui "Chatwoot", então a marca vazava em domínio de agência).

**Dois bugs de white-label anteriores, corrigidos junto:**

1. **A cor da agência sumia no tema escuro.** O ERB injetava em `:root`, mas o
   `_next-colors.scss` redeclara os mesmos tokens em `.dark`, e essa classe é
   aplicada num elemento interno (`v3/App.vue`, `themeHelper`). Custom property
   redeclarada num descendente vence o valor herdado do ancestral, `!important`
   ou não. Agora o ERB emite os dois seletores.
2. **`brand_rgb` só escurecia.** Ao ligar o `.dark` do item 1, o texto de acento
   da agência ia pra ~2,5:1 sobre o card escuro. O método passou a aceitar
   percentual negativo (clareia em direção ao branco) e o bloco `.dark` usa
   `-10`/`-35`. Contraste medido: 6,0:1. As expectativas do spec existente de
   `brand_rgb` continuam valendo (caminho positivo inalterado).

Regra de acento pra telas novas registrada em `identidade/design-guide.md`.

**Falta:** definir `DEFAULT_LOCALE=pt_BR` no EasyPanel (sem isso a tela abre em
inglês mesmo com a tradução pronta) e rebuildar a imagem.

### 🟡 Erro 500 do Super Admin — corrigido e publicado; falta deployar

O log de produção mostrou o trace: `No route matches {action: "index",
controller: "super_admin/agency_users"}` em `_navigation.html.erb:40`.
**Não tinha relação com `DISABLE_ENTERPRISE`** (as 3 hipóteses anteriores caíram).

Causa: a camada custom de agências registrou `resources :agency_users` só com
`new/create/show/destroy` (sem `index`, igual ao `account_users`), mas a sidebar
do Super Admin gera link de `index` pra todo recurso do Administrate e o
`agency_users` não estava na lista de exclusão da navegação. Corrigido
adicionando `"agency_users"` ao skip list em
`hdevCRM/app/views/super_admin/application/_navigation.html.erb:36`.

**Feito:** commit `161ee71`, já em `origin/main`.

**Falta:** rebuild da imagem no EasyPanel (é ERB, muda com o código — restart
não basta porque a imagem é buildada do repo). Depois, confirmar que
`/super_admin` abre e navegar pelas telas (Accounts, Agencies, Users, Settings)
pra garantir que não há outro recurso sem `index`.

Observação menor vista no log (não bloqueia): WARN `Session activity update
failed: wrong number of arguments (given 1, expected 0)` no login do Super Admin.

Rastreado até `app/controllers/concerns/track_session_activity.rb` — o concern é
incluído no `ApplicationController`, e o `SuperAdmin::ApplicationController` herda
dele via Administrate, então o `after_action` roda também no `/super_admin`.
A causa exata ficou em aberto: pela ordem do método, a exceção tem de vir da
linha 11 (`return unless current_user`), porque a linha 12 já barraria o resto
(`request.headers['client']` é header do dashboard, navegador não manda) — e
`current_user`, no escopo `:super_admin`, passa pelo Warden com as estratégias do
devise_token_auth no meio. Nada no nosso código sobrescreve `current_user`.

Como o `rescue StandardError` só logava `e.message`, o backtrace se perdia e o
bug era indiagnosticável. O log agora inclui classe + 3 primeiros frames — no
próximo login do Super Admin depois do rebuild, o log aponta o culpado direto.
Se confirmar que é ruído do Warden, a correção limpa é um
`skip_after_action :update_session_activity` no `SuperAdmin::ApplicationController`
(rastrear sessão de agente não faz sentido no Super Admin).

### ✅ Preflight da Fase 3 feito (auditoria estática, nada removido ainda)

Varredura de tudo que referencia `enterprise/` ou `Enterprise::` fora da pasta.
O gate da Fase 3 (48h com `DISABLE_ENTERPRISE` + o 500 confirmado) continua de pé
— quando abrir, a remoção vira commit mecânico com a lista abaixo.

**Falsos alarmes — confirmado que não quebram nada (não mexer):**

| Ponto | Por que é seguro |
|---|---|
| `config/routes.rb` (10 refs) | todas dentro de `if ChatwootApp.enterprise?`, que já é `false` hoje |
| `app/views/api/v1/models/_account.json.jbuilder:9` | `resource.respond_to?(:billing_currency) && Enterprise::Billing::Currencies...` — `billing_currency` só existe em `enterprise/app/models/enterprise/account.rb`, então o `&&` curto-circuita antes de resolver a constante |
| `_conversation.json.jbuilder:61-62` | usa `respond_to?(:sla_applicable?)` + a coluna `sla_policy_id` (do core) |
| `app/models/conversation.rb` | SLA só aparece no comentário de schema; não há associação |
| `app/models/message.rb:229,376` | `'Captain::Assistant'` é **string** em `sender_type`, não constante |
| `lib/captain/*`, `api/v1/accounts/captain/*`, `Captain::TasksPolicy` | zero dependência de `enterprise/lib/captain/` — a checagem do plano confirmou. Ficam |
| `app/javascript/dashboard/api/enterprise/*` | mora em `app/javascript`, não sai. Chama rotas de billing (só cloud) que já respondem 404 |

**O que o plano da Fase 3 não previu — adicionar ao commit:**

1. **`spec/models/enterprise/audit/conversation_spec.rb`** — está fora de
   `spec/enterprise/`, então o `git rm -r spec/enterprise/` do plano **não pega**.
   É exatamente o `NameError` que o plano queria evitar (o `.rspec` só tem
   `--require spec_helper`, sem `--exclude-pattern`). Remover junto.
2. **Factories de models enterprise**: `spec/factories/sla_policies.rb`,
   `spec/factories/applied_slas.rb`, `spec/factories/sla_events.rb` —
   `SlaPolicy`/`AppliedSla`/`SlaEvent` vivem todos em `enterprise/app/models/`.
3. **`Rakefile:6-7`** — `require enterprise/tasks_railtie.rb`. Tem guarda
   `File.exist?`, então não quebra; sai como código morto.
4. **Rake tasks órfãs**: `lib/tasks/apply_sla.rake` (usa `SlaPolicy`),
   `lib/tasks/captain_assistant_migration.rake` e `lib/tasks/captain_chat.rake`
   (usam os models Captain, que são enterprise). Resolução em runtime, então não
   derrubam boot — mas passam a estourar se alguém rodar.

**Confirmado também:** todos os 9 models `Captain::*` são de `enterprise/`, e o
`report_data_seeder.rb` os usa nas linhas 100-104, 239-269 — o plano já previa.

**Decisão (27/07): o Captain não é reconstruído — é substituído.** A IA própria
em `app/services/ai/` (MIT, commit `18e879b`) já cobre o que importa: cliente
Anthropic com quota por conta/agência, agente de atendimento com handoff, tool
calling neutro de provider e geração de fluxo de chatbot. Isso remove o último
argumento pra manter `enterprise/` e destrava a Fase 3. Detalhes e roadmap em
`_memoria/estrategia.md` (terceira trilha).

Dois pontos que a Fase 3 precisa tratar junto, além do que já está listado:

1. **`app/models/account.rb:34,57,60-61`** — `include CaptainFeaturable`,
   `include AccountCaptainAutoResolve` e os `store_accessor :settings` de
   `captain_models`/`captain_features`/`captain_auto_resolve_mode`. São MIT, mas
   só servem ao Captain; saem junto ou o boot quebra por constante faltando.
2. **`InstallationConfig::CAPTAIN_LLM_CONFIG_KEYS`** (`installation_config.rb:18-22`)
   e o bloco `# MARK: Captain Config` do `installation_config.yml` — some junto
   com o `# MARK: IA Config` que entrou no lugar em `18e879b`.

**Fica (não deletar):** `lib/llm/` e `config/llm.yml`. Eram peso morto do
Captain, mas com o multi-provider aprovado viraram o registry model→provider da
IA própria. Só `CaptainFeaturable` e o `captain_v2_assistant_model` hardcoded em
`lib/llm/feature_router.rb:4,32-37` saem.

**Bônus MIT:** o frontend do Captain (`app/javascript/dashboard/components-next/captain/`)
está **fora** de `enterprise/`, então é MIT e reutilizável — cards, playground,
empty states e gerenciador de documentos. Não redesenhar do zero.

### ✅ Fase 5 — superfície JS do widget (28/07, não deployada)

O gatilho: a tela "Sua caixa de entrada está pronta" mostrava
`window.chatwootSDK.run(...)` no snippet que a agência cola no site do cliente
dela. Era o vazamento mais público que restava.

Renomeado sem retrocompatibilidade (o banco tinha zero `Channel::WebWidget`, então
nenhum widget instalado quebrou): `chatwootSDK`→`hdevSDK`, `$chatwoot`→`$hdev`,
`chatwootSettings`→`hdevSettings`, `chatwootWebChannel`/`chatwootPubsubToken`,
prefixo postMessage `chatwoot-widget:`→`hdev-widget:`, eventos `chatwoot:*`→`hdev:*`,
as 7 constantes `CHATWOOT_*` do `sdkEvents.js`, id do DOM
`chatwoot_live_chat_widget`, chaves de localStorage `chatwoot_*`, e
`chatwoot_bot.png`→`hdev_bot.png`. 49 arquivos de código + 57 locales.

**Três coisas que quase passaram e valem lembrar:**

1. **O `WOOT_PREFIX` só era usado pra ler.** As escritas do postMessage eram
   literais hardcoded em `widget/helpers/utils.js` e nos 3 pontos do
   `sdk/IFrameHelper.js`. Trocar só a constante faria o widget escrever num
   prefixo e ler noutro — o iframe abre e nunca responde, sem erro no console.
2. **`dashboard/routes/dashboard/suspended/Index.vue`** escutava
   `chatwoot:on-message` do widget de suporte embutido no próprio dashboard —
   fora do escopo de `sdk/widget/entrypoints`, só apareceu no grep final.
   Mesma história com `ContactNoteItem.vue`, que referenciava o PNG do bot.
3. **`sed 's/$chatwoot/.../'` não casa nada** — `$` é âncora de regex e o sed
   não reclama. Precisa de `\$`.

**Fora de escopo por decisão:** classes `woot-*` (617 refs), cookies `cw_*`, ids
`cw-widget-holder`/`cw-bubble-holder`/`cw-widget-styles`. Não dizem "chatwoot"
pra ninguém — churn sem ganho de marca. E `window.chatwootConfig` (global do
**dashboard**, não do widget) fica pra Fase 6.

**Verificação:** 3.762 testes vitest verdes; as 18 falhas em 6 arquivos
(`timeHelper`, `availabilityHelpers`, `snoozeHelpers`, `ReportsDataHelper`,
`useReportMetrics`, `filterHelpers`) são **pré-existentes** — confirmado rodando
a mesma lista com as mudanças no stash. São testes dependentes de data.

**Falta:** rebuild da imagem no EasyPanel (restart não basta) e o teste manual em
`/widget_tests` — console deve logar `hdev:ready`, a bolha tem que abrir E fechar
(se abrir e ficar inerte, o prefixo postMessage dessincronizou), e o avatar do bot
deve buscar `/assets/images/hdev_bot.png` com 200.

### ⏳ Próximas fases (planejadas, não iniciadas)

| Fase | O que é | Pré-requisito |
|---|---|---|
| **3** | Remover `enterprise/` e `spec/enterprise/` de vez; deletar `lib/chatwoot_hub.rb` e toda a telemetria; remover `UpdateBanner`, changelog card, testimonials | 48h estável com `DISABLE_ENTERPRISE` + o 500 resolvido |
| **3b** | Textos e links visíveis: URLs `chatwoot.com` em `globals.js`, termos/privacidade no signup (~50 locales), `helpCenter.json`, e-mails (`accounts@chatwoot.com`), locales `ja`/`ko`/`sl`. **Achado em 28/07 no HTML servido — grep por `chatwoot.com` não pega:** o `helpUrls` inteiro aponta pra `https://chwt.app/hc/*` (o encurtador deles), então todo link de ajuda do dashboard leva pra documentação do Chatwoot; e o `window.globalConfig` ainda expõe as chaves `CHATWOOT_INBOX_TOKEN` e `chatwootConfig`. **Adiantado em 27/07 (na tradução pt-BR, sem commit): links do signup en+pt_BR → hdev.online/termos-de-uso e /politica-de-privacidade; remetente-fallback → 'Hdev CRM <sac@hdev.online>'. Faltam os outros ~50 locales e publicar as páginas** | precisa de páginas próprias de Termos e Privacidade publicadas |
| **5** | ✅ **Feita em 28/07, antecipada à Fase 3** (não havia acoplamento real: o SDK não referencia `enterprise/`). Ver bloco abaixo. Ficaram de fora por decisão: classes `woot-*` (617 refs) e cookies `cw_` — não soletram "chatwoot" | — |
| **6** | Identificadores internos Ruby (~357 refs), `db:chatwoot_prepare`, feature flags, chaves `CHATWOOT_*` | Fases 1-5 estáveis |

Plano detalhado com comandos, armadilhas e verificação por fase:
`C:\Users\hdev\.claude\plans\crie-um-plano-completo-buzzing-stardust.md`

---

## Armadilhas que já custaram tempo (não repetir)

- **`ENV.fetch('DISABLE_ENTERPRISE', false)` retorna string** — `"false"` também é
  verdadeiro em Ruby. Qualquer valor liga o kill-switch.
- **Nunca rodar `ConfigLoader.new.process(reconcile_only_new: false)`** — reescreve
  ~150 chaves e apaga credenciais (SMTP, integrações) configuradas pela UI.
- **Nunca rodar `db:seed` em produção** — cria a conta de exemplo "Acme Inc".
- **Nunca reordenar `config/features.yml`** — as flags são um bitset por posição;
  reordenar embaralha as features de todas as contas. Renomear o `name` é seguro.
- **`db:chatwoot_prepare` é chamado pelo `command` do `docker-compose.easypanel.yaml`**,
  não pelo entrypoint. Renomear a task sem atualizar o compose derruba a instância.
- **Mudança de JS/SCSS só aparece após rebuild da imagem** (o Dockerfile roda
  `assets:precompile` no build) — restart não basta.
- **E rebuild não basta pro `/packs/js/sdk.js`.** Esse arquivo sai do
  `vite.lib.config.ts` com nome fixo, sem hash, porque a URL vai dentro do snippet
  que a agência cola no site do cliente. Só que o `public_file_server` do
  `production.rb` carimba `max-age=1.year` em tudo dentro de `public/`. Resultado
  em 28/07: o Cloudflare serviu o SDK **antigo, ainda com `chatwootSDK`**, por horas
  depois do rebuild, enquanto o host do EasyPanel já servia o novo. Diagnóstico:
  baixar o arquivo dos dois hosts e comparar md5 (`cf-cache-status: HIT` + `Age`
  alto confirmam). Remédio imediato: purge no Cloudflare. Conserto: o middleware
  `config/initializers/widget_sdk_cache_control.rb` (escrito em 28/07), que baixa
  só esse asset pra `max-age=300, must-revalidate` — os assets com hash continuam
  com o ano inteiro. Vale pro navegador do visitante também, que purge nenhum alcança.
- **`INSTALLATION_NAME`/`BRAND_NAME` no bloco `environment` do compose são no-ops** —
  nenhum código lê essas chaves do ENV; os valores vêm da tabela `installation_configs`.
- **As chaves de marca nascem `locked: true`** e por isso não aparecem em
  `/super_admin/installation_configs`. Só dá para editá-las via `rails runner`.

## Pendências de infra herdadas

- **Backup do Postgres**: feito manualmente uma vez. Falta a rotina de cron diária.
- ~~**DNS `crm.hdev.online`**~~: **no ar desde 28/07**, atrás do Cloudflare, e
  `FRONTEND_URL` já apontava pra ele. O host `hdev-crm-app-crm.jz4bvz.easypanel.host`
  continua respondendo direto, sem CDN — guardar esse par, porque comparar os dois
  é o diagnóstico de cache envenenado (ver armadilha do `sdk.js` acima).
- **SMTP**: não configurado. Convites de agente e recuperação de senha não saem.
