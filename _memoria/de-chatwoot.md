# Projeto: desvincular o Hdev CRM do Chatwoot

> Documento de trabalho da migração. Atualizar ao fim de cada fase.
> Última atualização: **2026-07-30**

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

### ✅ Fase 3 EXECUTADA E MERGEADA (29/07) — `enterprise/` deletado

PR #2 (`fase3/remove-enterprise`), 4 commits, **mergeado na `main` em `c4e3f74`**
com CI verde nos três jobs — no PR e de novo na `main` depois do merge.
**`5989 examples, 0 failures, 64 pending` em 13m50s + rubocop `2148 files
inspected, no offenses` + vitest.** A suíte rodou **inteira, sem
`--exclude-pattern`, sem `enterprise/`** — o teste que o plano chamou de "o teste
de verdade". `db/schema.rb` conferido contra o artifact do CI: **idêntico**, não
houve migration nesta rodada.

**733 arquivos, −51.915 linhas.** Saiu: `enterprise/` (465), `spec/enterprise/`
(234), o `conversation_spec.rb` de fora, 9 factories + `spec/factories/captain/`,
4 rake tasks órfãs, `config/initializers/audited.rb` e
`lib/seeders/reports/assistant_conversation_creator.rb`. Editado:
`config/application.rb`, `Rakefile`, `_account.json.jbuilder`,
`report_data_seeder.rb`, `routes.rb` (6 blocos) e `ci.yml`.

**O probe do passo 1 valeu o run.** Fechou vermelho com 9 falhas, todas o mesmo
override: `enterprise/.../confirmation_instructions.html.erb` chamava
`account.saml_enabled?`, que só existe no módulo enterprise, enquanto
`config/application.rb` prependava `enterprise/app/views` **sem guarda nenhuma**
— dependia do arquivo existir no disco, não da env var. Estado que só existe com
`DISABLE_ENTERPRISE` ligado E os arquivos presentes; a deleção foi o conserto.
Lição: **view path do enterprise não era gateado, só o módulo era.**

**A contagem fecha exata** — nenhum spec foi comido pelo pattern:
`5994` (baseline) `−3` (os `super_admin/accounts_controller_spec.rb:30,50,69`
com `if: ChatwootApp.enterprise?` passam a pular) `= 5991` (probe) `−2` (o
`conversation_spec.rb` deletado, que tinha exatamente 2 exemplos e **nunca** foi
pego pelo `--exclude-pattern`, porque mora em `spec/models/enterprise/`, não em
`spec/enterprise/`) `= 5989`.

**Duas correções ao que estava registrado antes:**

1. **`CaptainFeaturable` e `AccountCaptainAutoResolve` FICAM** — a nota de 27/07
   dizia que sairiam junto "ou o boot quebra". Errado: os dois são MIT puros
   (usam `Llm::Models` do core e o hash `settings`), zero constante enterprise.
   O plano estava certo, a nota estava desatualizada.
2. **Uma ofensa de lint apareceu depois da deleção**: o seeder encolheu ~90
   linhas e o `# rubocop:disable Metrics/ClassLength` virou
   `RedundantCopDisableDirective`. Consertado no terceiro commit.

**Sobras de config que o plano não listava** e foram limpas junto: 4 referências
a `enterprise/` no `.rubocop.yml` (`Metrics/MethodLength`,
`Rails/HelperInstanceVariable`, `Rails/InverseOf`,
`Rails/UniqueValidationWithoutIndex`) e o `model_dir` do `.annotaterb.yml`.

**Falta só o servidor:** **rebuild** (não restart) no EasyPanel — depois,
conferir que `/super_admin` abre, o dashboard carrega, os menus Captain / SLA /
Audit Logs / Custom Roles / Negócios não aparecem, e login e envio de mensagem
funcionam. Risco baixo: produção já roda com `DISABLE_ENTERPRISE=true` desde
26/07, então em runtime a deleção é um no-op.

**Destravou a Fase 3b** (textos e links visíveis), que agora só depende das
páginas `hdev.online/termos-de-uso` e `/politica-de-privacidade` existirem.

### 📋 Revisão do plano da Fase 3 + corte da Fase 3.5 (29/07, análise)

Auditoria do plano `1-isso-ja-foi-starry-neumann.md` contra o repo. **O plano está
correto** — as três armadilhas (bitset do `features.yml`, `installation_config.yml`,
namespace `Captain::` dividido) e a regra mecânica das rotas conferem. Executar
como está escrito. O que muda é o **depois**.

**Enquadramento que faltava:** a Fase 3 não é mudança de produto, é mudança de
repositório. Com `DISABLE_ENTERPRISE=true` desde 26/07, as 14 famílias de feature
já estão desligadas em produção. E a deleção **não tira um único arquivo de
frontend nem uma única tabela**: `enterprise/` tem **zero** `.js`/`.vue`
(verificado). Cada feature é cortada em três camadas — o cérebro (model,
controller, jbuilder, job, service) sai; tabela + Vue + i18n + mailers ficam,
MIT.

**Fase 3.5 reordenada (decisão de 29/07):** as quatro reconstruções viram lista
de espera com **gatilho por pedido de cliente**, não roadmap — há zero agências
pagantes hoje e cada uma é código a manter sem demanda.

| Feature | Custo real | Decisão |
|---|---|---|
| **Companies** | ~200 linhas | **Cortada de vez.** Sobreposta pelo Kanban de Negócios (`deals`), que é o que agência usa. Um atributo customizado "empresa" no contato cobre o resto por zero linha |
| **Audit logs** | ~70 linhas (a gem `audited` faz o trabalho) | Primeira a voltar **se** um cliente pedir compliance |
| **Custom roles** | CRUD 106 linhas + **a matriz de permissões em ~20 policies** ← custo escondido | Adiar. Quando vier, 2-3 papéis fixos resolvem 90% |
| **SLA** | ~600 linhas, 3 tabelas, jobs | Adiar. Maior apelo comercial e maior custo — só quando houver a quem vender |

**As duas reconstruções que valem mais que as quatro (não estavam no plano):**

1. **Transcrição de áudio** (`enterprise/app/services/messages/audio_transcription_service.rb`)
   — áudio no WhatsApp é expectativa no Brasil, não feature. O contrato inteiro
   já é MIT e já está no core: toggle em `Settings > Account`, e
   `meta['transcribed_text']` já lido por `attachment.rb:113`, `message.rb:279`,
   `search_data_presenter.rb:37` e a busca do dashboard. Falta só quem preenche
   — ~60 linhas contra a Anthropic. O gatilho também é EE
   (`enterprise/app/models/enterprise/concerns/attachment.rb:21`), então tem que
   voltar junto.
2. **Campos de limite/feature do super admin** (`enterprise/app/fields/`) — sem
   eles não há UI pra ligar feature ou setar limite por conta, que é literalmente
   a mecânica dos planos de revenda. É um `Administrate::Field` de ~20 linhas.
   `app/dashboards/account_dashboard.rb:11` já está gateado por
   `ChatwootApp.enterprise?`, então **a deleção não quebra o `/super_admin`** —
   os campos só somem, como já sumiram em produção.

**Canais oficiais não estão em risco — confusão desfeita em 29/07.** A API oficial
do WhatsApp (Meta Cloud) e o Twilio continuam sendo oferecidos e **são 100% core
MIT**: `app/models/channel/whatsapp.rb` + 34 arquivos em `app/services/whatsapp/`
(embedded signup, templates, webhooks, `providers/whatsapp_cloud_service.rb`), e
`app/models/channel/twilio_sms.rb` + 18 arquivos (`send_on_twilio_service`,
delivery status, callbacks). 360Dialog e Baileys idem. **A deleção não encosta em
nenhum deles.**

O que `enterprise/` tem de WhatsApp/Twilio é **só chamada de voz**, verificado
arquivo por arquivo: Twilio Voice (16 arq. — ligação, conferência, gravação,
token WebRTC) e WhatsApp Calling API (7 arq., exige Graph v17+ e aprovação da
Meta). O override `Enterprise::Channel::TwilioSms` só adiciona `voice_enabled`,
provisionamento de TwiML App e `initiate_call` — zero linha de envio de mensagem;
e o `Enterprise::Webhooks::WhatsappEventsJob` intercepta apenas
`field == 'calls'`, todo o resto cai no `super` do core.

**Decisão (29/07): voz sai junto e volta reconstruída se precisar.** Entra na
fila da Fase 3.5 com gatilho por necessidade, sem prioridade. O Vue de voz (9
arquivos) é core e fica pronto pra ser religado. Custo quando vier: é a
reconstrução mais cara da lista — WebRTC + conferência + gravação +
armazenamento + consentimento de gravação (LGPD), maior que o SLA.

**Dois órfãos que o plano não lista** (além do `sla_activity_message_handler.rb`
que ele decide preservar):

- `app/jobs/companies/fetch_avatars_job.rb` — core, chama `account.companies` sem
  guarda de `enterprise?`. **Zero chamadores** (grep confirmado), então não
  quebra. Mesma categoria do handler de SLA: fica ou sai junto, mas não é o
  único caso.
- Os enums `sla_missed_*` em `notification.rb:44-46` + os 3 mailers `.liquid`
  ficam no core. Nada os emite sem o SLA — texto morto, inofensivo.

**Ressalva do plano sobre o histórico do git: resolvida.** O repo
`solutionshdev-sudo/hdev-crm` é **privado** (confirmado via `gh`), então não há
exposição pública de licença a fechar. Só vale reavaliar se um dia for aberto.

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

### ✅ Fase 3-tele EXECUTADA E MERGEADA (29/07) — telemetria e hub cortados

PR #3 (`fase3/remove-telemetry`), mergeado em `59025f0` com **CI verde nos três
jobs**: `5975 examples, 0 failures, 64 pending` (11min21s), rubocop+eslint
`2142 files inspected, no offenses` e vitest `382 arquivos, todos passando`.
107 arquivos, −1.401 linhas. Nenhuma linha do app fala com `hub.2.chatwoot.com`.

**A pendência registrada como bloqueio não existia.** A nota dizia que os dois
serviços de push usavam o hub como "relay de VAPID" e precisariam de substituto
antes do corte. **Era FCM, não VAPID.** Web push sempre foi local
(`WebPush.payload_send` com as chaves do `VapidService`); o relay só existia pro
push do app **mobile**, e o substituto — `send_fcm_push` com credencial Firebase
própria — já estava no arquivo, logo acima. O que vazava: título e corpo da
notificação iam pro servidor deles quando a instância não tinha Firebase.

Saiu: `lib/chatwoot_hub.rb`, `register_instance` no onboarding (empresa, nome e
e-mail do dono) + o checkbox que o disparava, `Internal::CheckNewVersionsJob` e
`Internal::TriggerDailyScheduledItemsJob` (o segundo **só existia** pra agendar o
primeiro), a entrada do `schedule.yml`, a chave Redis `LATEST_CHATWOOT_VERSION`,
o campo `latest_chatwoot_version` da API de conta + swagger, a action `refresh`
do super admin (já sem link na tela), `UpdateBanner`+`versionCheckHelper` (chave
`UPDATE_CHATWOOT` fora dos 57 locales), o changelog do sidebar e os testimonials
do signup.

**Dois achados de brinde:**

1. **`'saml'` no `allowed_login_methods` era código morto desde a Fase 3** —
   dependia de `ChatwootHub.pricing_plan != 'community'`, e `pricing_plan`
   retorna `'community'` incondicionalmente desde que `enterprise/` sumiu.
2. **`ExceptionList::REST_CLIENT_EXCEPTIONS` ficou sem consumidor**, e com ele a
   gem `rest-client` ficou sem uso real. A constante saiu; **a gem não** —
   remover exige regenerar o `Gemfile.lock` com bundler (rodada com Ruby).

**Armadilha do swagger:** os 5 JSONs foram editados **por texto**, não por
`JSON.parse`+`stringify`. O round-trip reordena as chaves numéricas de status
HTTP (`"404"` antes de `"403"`, porque JS ordena chaves integer-like) e
reescreveria o arquivo inteiro. Fonte de verdade é o `.yml` em
`swagger/definitions/`; os JSONs são gerados por rake que precisa de Ruby.

**`DISABLE_TELEMETRY` e `ENABLE_PUSH_RELAY_SERVER` viraram no-op** e saíram do
compose e do `INSTALAR-EASYPANEL.md` — nenhum código lê essas chaves. Push mobile
agora exige `FIREBASE_PROJECT_ID` + `FIREBASE_CREDENTIALS` no super admin.

**Confirmado:** as 18 falhas de vitest em 6 arquivos que aparecem na máquina do
Harvey **passam no CI**. São dependentes de data/fuso, não de código — a
suspeita registrada na Fase 5 está fechada.

### ✅ Fase 3b EXECUTADA E MERGEADA (30/07) — textos e links visíveis

PR #5 (`fase3b/textos-links`), mergeado em `76eddb7` com **CI verde nos três
jobs**: `5975 examples, 0 failures, 64 pending` (16m42s), lint (2m43s) e vitest
(12m49s).

**O pré-requisito que travava esta fase era falso.** A tabela abaixo dizia
"precisa de páginas próprias de Termos e Privacidade publicadas". Não precisa:
`TERMS_URL` e `PRIVACY_URL` são chaves de `installation_configs`
(`installation_config.yml:45-52`, hoje valendo `'#'`), lidas pelo
`dashboard_controller.rb:11-14` e entregues ao front como
`globalConfig.termsURL`. E `agency.rb:75-76` já as sobrescreve **por agência** —
o mecanismo de cada revendedora apontar pros próprios termos existe e está
pronto. Pra hospedar, o Help Center do produto já serve
`/hc/:slug/:locale/articles/:article_slug` (`routes.rb:585-596`), público e sem
autenticação: dois artigos pela UI e as duas chaves apontadas resolvem, com
zero linha de código. **Segundo bloqueio fantasma seguido**, depois do "relay de
VAPID" da Fase 3-tele — vale desconfiar de pré-requisito registrado sem prova.

**O bug que a fase achou é nosso, não do upstream.** O
`v3/.../Signup/Form.vue` aplicava a config por substituição de string literal:

```js
t('REGISTER.TERMS_ACCEPT').replace('https://www.chatwoot.com/terms', globalConfig.value.termsURL)
```

A tradução pt-BR de 27/07 cravou `hdev.online` no texto de `en` e `pt_BR`. O
`.replace` deixou de casar e **`TERMS_URL` virou no-op nos dois locales que a
instância usa** — toda agência revendedora exibia os termos da HDEV no próprio
cadastro. Nos outros 55 a config ainda funcionava, mas só porque o fallback
visível continuava sendo `chatwoot.com`. Agora é interpolação do vue-i18n
(`{termsUrl}`/`{privacyUrl}`) nos 57 locales, o que conserta o override e limpa
o `chatwoot.com` do signup na mesma linha.

Rede de proteção: `app/javascript/dashboard/i18n/specs/signupTerms.spec.js` lê
os 57 arquivos e falha se algum voltar a cravar URL. Verificado revertendo um
locale — falha só nele, 57 passam.

**`helpUrls` era código morto que só publicava a documentação deles.** A cadeia
`feature_help_urls` (`application_helper.rb`) → `vueapp.html.erb:86` →
`window.globalConfig.helpUrls` emitia os `chwt.app/hc/*` em toda página servida
e **não tinha nenhum consumidor no frontend** (grep confirmado). Deletada
inteira, junto com os 12 `help_url` do `features.yml` — **só as sub-chaves; a
ordem do bitset não foi tocada**. O mapa do `featureHelper.js` (esse sim vivo,
consumido pelo `BaseSettingsHeader`) ficou vazio de propósito: o componente já
gateia em `v-if="helpURL && linkText"`, então o link some sozinho.

**Fallback de remetente tem duas dependências em spec, não uma.** Trocar
`accounts@chatwoot.com` → `sac@hdev.online` (em `email_address_parseable.rb`,
`mail_presenter.rb` e `devise.rb`, alinhando ao que os mailers já usavam) quebra:
1. `reply_mailbox_spec` — usa a fixture `notification.eml`, cujo `From:` precisa
   casar com o fallback, e **não stuba a env**. Antecipado, corrigido junto.
2. `confirmation_instructions_spec:20` — assertava o `reply_to`. **Só apareceu
   no CI**, porque o grep por `accounts@chatwoot` rodou antes da decisão de
   mexer no `devise.rb`. Foi a única falha do run.

O `mail_presenter_spec:255` **não** quebra: usa `with_modified_env`.

**Critério de escopo (o mesmo das classes `woot-*`):** links atrás de
`isOnChatwootCloud` e de `showOnCustomBrandedInstance` ficaram de fora. O fork
força `isACustomBrandedInstance: () => true` e `isAChatwootInstance: () => false`
em `shared/store/globalConfig.js`, e `deploymentEnv` nunca é `'cloud'` — esse
código **não renderiza**. Isso cobre `HELP_CENTER_DOCS_URL` (só alcançável pelo
bloco de upsell do `UpgradePage`), `META_RESTRICTION_STATUS_URL` e os
`learn-more-url` do Captain. Saíram de graça, por serem deleção pura: o menu
Docs/Changelog do `SidebarProfileMenu` e o `DOCS_URL` sem consumidor.

Corrigidos por serem visíveis de verdade: link de docs do HMAC
(`ConfigurationPage.vue`), guia de migração do WhatsApp (banner + dialog), dados
de amostra das campanhas (`chatwoot.com` → `example.com`, e a mensagem do cupom
do G2) e a descrição do `AZURE_APP_ID`.

**Achado que não é link e vale mais que a fase:** o **Captain tem rota
registrada no front** (`captainRoutes` em `dashboard.routes.js`) **mas zero model
no backend desde a Fase 3** — `app/models/captain*` não existe. Se aquela tela
abrir, dá 500. Problema separado, maior que texto.

**Falta:** o rebuild no EasyPanel (junto com o acumulado das Fases 5 e 3) e
criar os dois artigos no Help Center — enquanto `TERMS_URL`/`PRIVACY_URL` valerem
`'#'`, o link do cadastro obedece à configuração mas não leva a lugar nenhum.

### ✅ Fase 6 — as 7 constantes Ruby FEITAS (30/07, PR #7 verde, ainda draft)

PR #7 (`fase6/renames-internos`), 8 commits, **CI verde nos três jobs**:
`5996 examples, 0 failures, 64 pending` (16m03s). **Deixado como draft de
propósito:** se entrar antes do rebuild da Fase 3b, o mesmo deploy carrega
rename de constante e mudança de front, e qualquer quebra fica ambígua.

| Constante | Refs | Zeitwerk |
|---|---|---|
| `ChatwootFbProvider` → `HdevFbProvider` | 2 | não — `config/initializers` |
| `ChatwootDequeuedLogger` → `HdevDequeuedLogger` | 2 | não — idem |
| `ChatwootMarkdownRenderer` → `HdevMarkdownRenderer` | 12 | sim |
| `ChatwootCaptcha` → `HdevCaptcha` | 14 | sim |
| `ChatwootExceptionTracker` → `HdevExceptionTracker` | 68 | sim |
| `ChatwootApp` → `HdevApp` | 96 | sim |
| `module Chatwoot` → `module HdevCrm` | **30** | não — `application.rb` |

**As duas armadilhas de grep que custaram dois runs vermelhos** — valem além
desta fase, porque são erros de medição, não de código:

1. **`Chatwoot::` não casa `Chatwoot.`** O namespace expõe quatro métodos de
   módulo (`config`, `redis_ssl_verify_mode`, `encryption_configured?`,
   `mfa_enabled?`) usados em 30 lugares como `Chatwoot.metodo`. A contagem
   inicial deu "2 refs" porque contou a string literal `module Chatwoot`, não a
   constante. **O grep certo para namespace é `\bChatwoot[.:]`.**
2. **Filtrar por extensão esconde ERB dentro de YAML.** `config/cable.yml:6`
   tem `<%= Chatwoot.redis_ssl_verify_mode %>`, lido pelo `config_for` do
   ActionCable. Nenhum grep restrito a `.rb`/`.erb` acha. A varredura final
   correta é sem filtro de extensão, sobre `app/ lib/ config/ spec/ bin/ db/
   Rakefile config.ru Gemfile`.

Ambas quebraram o **boot** (`NameError` no `db:create`), então o rspec morreu em
~90s sem rodar um teste. Foi barato exatamente porque cada constante subiu
sozinha e foi validada antes da próxima — o CI é o único `zeitwerk:check`
disponível sem Ruby na máquina.

**Duas correções ao plano de 26/07, confirmadas no código:**

- **A pior armadilha não existe neste repo.** O plano avisava sobre
  `Chatwoot::Application` em `config.ru`, `Rakefile`, `bin/*` e
  `config/environments/*`. Nenhum desses arquivos cita o namespace — usam
  `Rails.application` e `APP_PATH`.
- **Duas constantes não passam pelo Zeitwerk**, por viverem em
  `config/initializers`: sem regra de arquivo casado com constante, sem `git mv`.

**Dois achados de brinde:** `def bot; Chatwoot::Bot; end` no initializer do
facebook-messenger apontava para constante que **não existe** no repo, e `bot`
não faz parte da interface `Providers::Base` da gem (conferido na fonte) —
código morto, apagado. E `sent_from_chatwoot_app?` no parser do Facebook, que o
grep da constante não pegava por ser nome de método.

**NÃO mexido, de propósito — mesma categoria: custo de runtime, não de código.**
As duas são uma linha; o que decide é a janela de deploy:

- `_chatwoot_session` (`config/initializers/session_store.rb`) — a chave do
  cookie é **explícita**, não derivada do nome da classe da app (por isso o
  rename do namespace não deslogou ninguém). Trocar invalida a sessão de todos
  os agentes.
- `channel_prefix: "chatwoot_#{Rails.env}_action_cable"` (`config/cable.yml:7`)
  — trocar rompe as assinaturas de ActionCable em voo durante o deploy.

**O que falta da Fase 6** (nada disso é `git push` e pronto):
`db:chatwoot_prepare`, as 2 feature flags e as chaves `CHATWOOT_*` — detalhes na
contagem abaixo.

### 📋 Auditoria da Fase 6 (30/07)

O plano da Fase 6 é de 26/07 e **está desatualizado** — as Fases 3 e 3-tele
comeram pedaços dele. Contagem real hoje:

| Constante | Refs | Nota |
|---|---|---|
| `ChatwootApp` | 96 | o maior blast radius que restou |
| `ChatwootExceptionTracker` | 68 | |
| `ChatwootCaptcha` | 14 | |
| `ChatwootMarkdownRenderer` | 12 | |
| `ChatwootDequeuedLogger` | 2 | |
| `ChatwootFbProvider` | 2 | começar por aqui |
| `module Chatwoot` | 2 | o namespace da app |
| ~~`ChatwootHub`~~ | **0** | deletado na Fase 3-tele |
| ~~`Chatwoot::Application`~~ | **0** | |

**`db:chatwoot_prepare` tem 5 chamadores, não 1.** Além do
`docker-compose.easypanel.yaml:70` que o `CLAUDE.md` já avisa (renomear sem
atualizar = restart loop): `.circleci/config.yml:288`,
`.devcontainer/devcontainer.json:37` e **duas** ocorrências em
`deployment/setup_20.04.sh` (411 e 706 — a segunda dentro de uma string, que
busca-e-substitui pega mas revisão por diff passa batido).

**As duas feature flags moram em só 2 arquivos:** `chatwoot_v4` e
`contact_chatwoot_support_team` em `config/features.yml:138,146` e
`featureFlags.js:41,45`. Renomear o `name:` não mexe na ordem do bitset, mas a
migration pro `ACCOUNT_LEVEL_FEATURE_DEFAULTS` continua obrigatória — o
`ConfigLoader` faz merge por `uniq` e sem ela a flag velha fica órfã no JSON.

### ⏳ Próximas fases (planejadas, não iniciadas)

| Fase | O que é | Pré-requisito |
|---|---|---|
| **3** | ✅ **Feita em 29/07** — `enterprise/` e `spec/enterprise/` deletados, PR #2 mergeado em `c4e3f74`, CI verde. Ver o bloco "Fase 3 EXECUTADA" acima. Falta o rebuild no EasyPanel | — |
| **3-tele** | ✅ **Feita em 29/07** — `lib/chatwoot_hub.rb` e toda a telemetria deletados, PR #3 mergeado em `59025f0`, CI verde. Ver o bloco "Fase 3-tele EXECUTADA" acima. Falta o rebuild no EasyPanel | — |
| **3b** | ✅ **Feita em 30/07** — PR #5 mergeado em `76eddb7`, CI verde. Ver o bloco "Fase 3b EXECUTADA" acima. O pré-requisito registrado aqui (páginas próprias publicadas) era **falso**: os links são configuráveis e o Help Center do produto hospeda. Sobrou do escopo original, de propósito, o que não renderiza (gated por `isOnChatwootCloud`/`showOnCustomBrandedInstance`); `CHATWOOT_INBOX_TOKEN` e `chatwootConfig` no `window.globalConfig` são identificadores internos e ficam pra Fase 6. Falta o rebuild e criar os dois artigos | — |
| **5** | ✅ **Feita em 28/07, antecipada à Fase 3** (não havia acoplamento real: o SDK não referencia `enterprise/`). Ver bloco abaixo. Ficaram de fora por decisão: classes `woot-*` (617 refs) e cookies `cw_` — não soletram "chatwoot" | — |
| **6** | 🟡 **Constantes feitas em 30/07** (PR #7, verde, **draft** até o rebuild da 3b): as 7 renomeadas, +220 refs — o namespace sozinho tinha 30, não 2. Ver o bloco "Fase 6 — as 7 constantes Ruby FEITAS" acima, inclusive as duas armadilhas de grep. **Falta:** `db:chatwoot_prepare` (5 chamadores, 2 deploys), as 2 feature flags (migration obrigatória) e as chaves `CHATWOOT_*` (o HMAC assina webhooks). Mais 2 decisões de janela: `_chatwoot_session` e o `channel_prefix` do cable.yml | Fases 1-5 estáveis — **satisfeito** |

Plano detalhado com comandos, armadilhas e verificação por fase:
`C:\Users\hdev\.claude\plans\crie-um-plano-completo-buzzing-stardust.md`

Plano específico da Fase 3 (deleção do `enterprise/`, auditado e aprovado em
29/07 — ver o bloco "Revisão do plano da Fase 3" acima):
`C:\Users\hdev\.claude\plans\1-isso-ja-foi-starry-neumann.md`

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
