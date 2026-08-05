# Plano — Comercialização, IA por caixa e os três painéis (F6–F11)

> Aprovado em 2026-08-05. Execução pausada antes da F6 — nenhuma linha implementada.
> Contexto completo da decisão: conversa de 05/08 (análise do painel super admin,
> análise do DeskcommCRM como referência, decisões de hierarquia/cobrança/RAG).

## Contexto

O HDEV CRM já tem o motor (F1–F5): barramento de deals, anti-ban, kanban, IA operadora com
tool calling, quota por conta/agência e suspensão propagando. O que falta é a **camada
comercial**: o `Plan` existe mas seus limites nunca são lidos, não há CRUD de plano nem de
assinatura no painel, o webhook do Stripe não tem rota viva, e o modelo de IA é uma string
livre que qualquer conta pode trocar por um modelo 5× mais caro.

Em paralelo, a Fase 3 deletou `enterprise/` (decisão de licença, correta e definitiva) e
levou junto o backend do assistente de IA do upstream — mas **deixou o schema completo no
banco e o frontend inteiro no core MIT**. A base de conhecimento por caixa de entrada, que
é a funcionalidade mais pedida, é hoje uma camada Ruby faltando entre duas pontas prontas.
Os nomes herdados dessas duas pontas carregam identificador do upstream e serão renomeados
na F9 (ver decisão de naming abaixo).

A análise do DeskcommCRM (MIT, Rafael Melgaço — `C:\Users\hdev\Downloads\DeskcommCRM-main`)
validou vários desenhos e corrigiu outros: catálogo de modelos como tabela global, preço
versionado em vez de constante, credencial cifrada com validação prévia, quota por contador
atômico em vez de `SUM()` por request, e agente versionado com ponteiro imutável.

**Resultado esperado:** um CRM que pode ser vendido em dois modos (direto e white-label de
agência), com limites reais aplicados por plano, IA gateada por plano, cérebro configurável
por caixa de entrada, e três painéis com fronteiras claras.

### Decisões tomadas

| Decisão | Escolha |
|---|---|
| Hierarquia | Conta direta **é** a empresa — nível final, sem filhas. Sem schema novo. |
| Cobrança | **Agência paga (revenda).** Só a agência tem `Subscription`; contas-filhas recebem alocação. |
| RAG | **Sim na F9**, com embedding da OpenAI (`text-embedding-3-small`, casa com `vector(1536)` já no schema). |
| Ordem | **F6 primeiro** (planos e limites) — é o desbloqueador. |
| Naming | **Zero "Captain" em qualquer lugar** — inclusive nomes de tabela no banco. É identificador do Chatwoot e a regra de rebrand do CLAUDE.md manda remover toda menção. Namespace escolhido: `Ai::Assistant` / tabelas `ai_assistant*` (encaixa no `Ai::` que já existe). Rótulo de UI é chave I18n, decidido à parte. |

---

## Arquitetura de limites (vale para todas as fases)

A conta nunca tem plano próprio no modo agência. A resolução sobe a cadeia:

```
account.plan_allocations (a agência distribui)
    ↓ ausente
account.subscription.plan          (venda direta)
    ↓ ausente
account.agency.subscription.plan   (revenda — o pool da agência)
    ↓ ausente
nil = ilimitado (grandfathering de quem não tem plano)
```

Isso espelha o que `Ai::QuotaService#effective_limit`
(`hdevCRM/app/services/ai/quota_service.rb:86`) já faz para tokens. **Reusar aquele método
como referência de contrato**, não reescrever a lógica em cada fase.

---

## F6 — Planos e limites (desbloqueador)

**Objetivo:** transformar `Plan` de tabela decorativa em regra de negócio, e dar ao super
admin o CRUD no painel.

### Schema

| Migration | O quê |
|---|---|
| `add_channel_limits_to_plans` | `plans.channel_limits jsonb default '{}'` — `{"Channel::Whatsapp": 1, "Channel::FacebookPage": 1}`. Canal novo não pede migration. |
| `add_plan_allocations_to_accounts` | `accounts.plan_allocations jsonb default '{}'` — a fatia que a agência deu àquela conta. Mesmas chaves de `Plan::LIMIT_ATTRIBUTES` + `channel_limits`. |

Manter `max_agents`, `max_inboxes`, `max_baileys_instances`, `max_client_accounts` e
`ai_monthly_tokens` como estão — eles passam a ser **lidos** (hoje são colunas mortas:
nada no código de aplicação os consulta).

### Código novo

- **`app/services/plan/limit_enforcer.rb`** — o único lugar que responde "pode?".
  ```ruby
  Plan::LimitEnforcer.new(account: account).allow!(:inbox, channel_type: 'Channel::Whatsapp')
  Plan::LimitEnforcer.new(agency: agency).allow!(:client_account)
  ```
  Levanta `Plan::LimitExceededError` com a chave I18n do limite estourado.
  Resolve pela cadeia acima; `nil` = ilimitado (nunca bloqueia).

- **`app/dashboards/plan_dashboard.rb`** + `SuperAdmin::PlansController` + rota em
  `config/routes.rb:676` (dentro de `namespace :super_admin`, antes de `:accounts` para a
  ordem da sidebar).

### Pontos de aplicação (5)

| Onde | Limite | Nota do reconhecimento de código |
|---|---|---|
| Criação de inbox (`api/v1/accounts/inboxes_controller.rb` `#create`) | `max_inboxes` + `channel_limits[type]` | — |
| `api/v1/accounts/agents_controller.rb` | `max_agents` | Já tem `validate_limit` + `validate_limit_for_bulk_create` (L90-106) lendo `Account#usage_limits`, que hoje devolve `HdevApp.max_limit` (100.000 fixo, `account.rb:164`). **Trocar a fonte de `usage_limits` pelo enforcer** — os dois callbacks do controller continuam funcionando sem mudança. |
| Criação de instância Baileys | `max_baileys_instances` | — |
| `api/v1/agencies/accounts_controller.rb` `#create` (L14) | `max_client_accounts` | Hoje cria sem nenhuma checagem. |
| `Ai::QuotaService` | `ai_monthly_tokens` | Já funciona; passa a consultar `plan_allocations` primeiro. |

### Verificação

- CI: specs de `Plan::LimitEnforcer` cobrindo cadeia completa (alocação → conta → agência → nil),
  limite por canal, e cada um dos 5 pontos de aplicação recusando na borda.
- Baixar o artifact `schema` do CI e commitar o `db/schema.rb` regenerado.

---

## F7 — Stripe e assinatura

**Objetivo:** fechar o ciclo do dinheiro. Hoje `Subscription#activate!`, `#mark_past_due!` e
`#cancel!` (`subscription.rb:38-60`) **não têm chamador**.

### Mudanças

- **Tirar a rota do bloco morto.** `post 'webhooks/stripe'` está dentro de
  `if HdevApp.enterprise?` (`routes.rb:510-530`), que é `false` desde a Fase 3. Mover para
  fora, junto dos outros webhooks.
- **`app/controllers/webhooks/stripe_controller.rb`** — verifica assinatura HMAC do Stripe,
  grava em `StripeWebhookEvent` (o model de idempotência **já existe**, sem controller), e
  despacha: `checkout.session.completed` → `activate!`, `invoice.paid` → `activate!`,
  `invoice.payment_failed` → `mark_past_due!`, `customer.subscription.deleted` → `cancel!`.
- **`app/dashboards/subscription_dashboard.rb`** — ver e trocar plano de agência/conta pelo painel.
- **Checkout** — `api/v1/subscriptions#checkout` cria a sessão Stripe a partir de
  `plan.stripe_price_id`.

Reusar `config/initializers/stripe.rb` (já configurado com `STRIPE_SECRET_KEY`).

### Verificação
Spec de request com payloads fixos do Stripe; asserção de idempotência (mesmo `event_id` duas
vezes = uma mutação só).

---

## F7.5 — Quota por contador atômico (1 dia, alto retorno)

**Problema:** `QuotaService#account_usage` (`quota_service.rb:56`) roda `SUM(total_tokens)`
sobre `ai_usage_events`, e o `ToolLoop` chama isso **até 8 vezes por resposta**. O
`check_thresholds!` ainda dispara o mailer **dentro da request**.

### Mudanças

- Migration `create_ai_usage_counters`: `owner` polimórfico (Account|Agency), `period_start date`,
  `tokens bigint`, `cost_cents bigint`, unique `(owner_type, owner_id, period_start)`.
- `AiUsageEvent after_create` incrementa via `update_counters` — **mesmo padrão já usado em**
  `AiCreditEvent#record!` (`ai_credit_event.rb:38`).
- `QuotaService#account_usage`/`#agency_usage` passam a ler o contador.
- `check_thresholds!` vira `Ai::QuotaAlertJob` (Sidekiq). O cooldown Redis de 24h continua igual.

### Verificação
Spec comparando contador vs. `SUM()` após N eventos; spec garantindo que o mailer não é
chamado de forma síncrona.

---

## F8 — Conexões de IA, catálogo e gate por plano

**Objetivo:** o modelo deixa de ser string livre. O super admin passa a controlar provider,
modalidade (API direta / Bedrock / Vertex), preço e quem pode usar o quê.

### Schema (4 tabelas)

**`ai_connections`** — a credencial. Só o super admin mexe.
```
provider (anthropic|openai|google) · modality (direct|bedrock|vertex)
label · api_key (encrypted) · region · aws_access_key_id/secret (encrypted, p/ bedrock)
validated_at · validation_error · models_available (jsonb) · active
unique (provider, modality, label)
```
**Reusar o padrão de criptografia que já existe no repo:**
`encrypts :api_key if HdevCrm.encryption_configured?` — idêntico a `channel/telegram.rb:21`
e a mais 12 models. Shared example pronto:
`spec/support/examples/encrypted_external_credential_examples.rb`.

**`ai_models`** — catálogo global curado.
```
canonical_id (ex: "claude-haiku-4-5") · provider_model_id (ex: "anthropic.claude-haiku-4-5")
ai_connection_id · display_name · description · context_window
supports_tools · default_for_provider · deprecated_at
unique (canonical_id)
```
`canonical_id` é o que aparece na UI e é gravado em `AiUsageEvent`. `provider_model_id` é o
que vai no wire. **É essa separação que faz Bedrock ser uma troca de uma linha.**

**`ai_model_prices`** — preço com histórico.
```
ai_model_id · input_cents_per_million · output_cents_per_million
embedding_cents_per_million · effective_from · superseded_at
```
Substitui a constante `Ai::Pricing::PRICES` (`lib/ai/pricing.rb:6`). `superseded_at`
preserva o custo histórico quando o preço muda.

**`plan_ai_models`** — join `plan ↔ ai_model`. É o gate.

### Código

- **`Ai::ModelResolver`** — `canonical_id` → `(connection, provider_model_id)`, com validação
  de que o modelo está no plano da conta.
- **`Ai::AnthropicService#client`** (`anthropic_service.rb:86`) passa a receber o cliente
  injetado em vez de construir. Direta e Bedrock viram a mesma classe.
- **`Ai::Pricing`** passa a ler de `ai_model_prices` com cache de 5 min em memória; arredondar
  **para cima** (errar a favor da cobrança).
- **Gate nas duas pontas:**
  - `ai_agents_controller.rb:18` valida `ai_agent_model` contra o plano antes de salvar.
  - `Ai::AnthropicService#raw_chat` valida antes de executar — **essencial**, porque um
    downgrade de plano deixa o modelo caro salvo em `custom_attributes`.
- **UI:** `aiAgent/Index.vue` tem `MODEL_OPTIONS` **hardcoded no arquivo Vue** (L11-16);
  passa a buscar do servidor, já filtrado.
- **Dashboards:** `AiConnectionDashboard` (nunca expor a chave — só os 4 últimos dígitos),
  `AiModelDashboard`, `AiModelPriceDashboard`.

### Verificação
Spec de resolução por modalidade; spec de gate recusando modelo fora do plano no controller
**e** no service; spec garantindo que a chave nunca aparece em log/serialização.

---

## F9 — Cérebro por caixa de entrada

**Objetivo:** cada caixa com suas instruções, guardrails, documentos e FAQ. Escrever a camada
Ruby **MIT do zero** sobre o schema que já está no banco.

> ⚠️ **Regra inegociável 1:** não recuperar código de `enterprise/` do histórico do git. O
> schema (`db/schema.rb`) e o frontend Vue são do core MIT e são reaproveitáveis; models,
> services e controllers se escrevem novos.
>
> ⚠️ **Regra inegociável 2 (decisão de 05/08):** o nome "Captain" não sobrevive em lugar
> NENHUM — nem classe, nem rota, nem chave de config, **nem nome de tabela no banco**. É
> identificador do Chatwoot e a regra de rebrand manda remover toda menção. Tudo vira
> `Ai::Assistant` / `ai_assistant*`.

### Schema — renomear o herdado, não criar do zero

A **estrutura** das tabelas do Captain é reaproveitável (colunas, índices, o
`vector(1536)` com ivfflat); os **nomes** não. Uma migration de rename resolve — rename
preserva índices e tipos, e as tabelas estão vazias (o backend que as populava foi
deletado na Fase 3 com a feature flag `enabled: false` desde sempre).
**Conferir que estão vazias em produção (terminal EasyPanel) antes de rodar.**

| Migration | O quê |
|---|---|
| `rename_captain_tables_to_ai_assistants` | `captain_assistants` → `ai_assistants` · `captain_inboxes` → `ai_assistant_inboxes` · `captain_documents` → `ai_assistant_documents` · `captain_assistant_responses` → `ai_assistant_responses`. Índices e a coluna `embedding vector(1536)` vêm junto no rename. Renomear também os índices (`index_captain_*` → `index_ai_assistant_*`) pra varredura futura por "captain" não achar nada. |
| `drop_unused_captain_tables` | `captain_custom_tools`, `captain_scenarios`, `captain_faq_observations`, `captain_faq_suggestions`, `captain_message_reports` — sem uso planejado nas F6–F11 e vazias. Se algum conceito voltar (FAQ automático, cenários), renasce com nome `ai_assistant_*` na hora. |
| `create_ai_assistant_versions` + `ai_assistant_pointers` | Hoje o assistente seria editado **in-place** — sem rollback. Versões imutáveis + ponteiro dizendo qual está no ar. Padrão validado no Deskcomm (usado lá em 9 recursos). |
| `add_runtime_config_to_ai_assistants` | Campos que hoje são constantes no código: `max_steps` (hoje `MAX_ITERATIONS = 8` em `tool_loop.rb:15`, fixo pra todo mundo), `token_budget`, `cost_budget_cents` (teto **por cérebro** — hoje uma caixa descontrolada consome a quota da conta inteira), `history_message_window` (hoje `HISTORY_LIMIT = 20`), `handoff_keywords` (hoje regex fixa), `trigger_config` jsonb (ignorar grupo/self, horário comercial). |

### Varredura de resíduo "captain" fora do banco (mesma fase)

O nome está espalhado em mais lugares além das tabelas — a F9 limpa tudo de uma vez:

- **Ruby:** `app/controllers/api/v1/accounts/captain/` (preferences, tasks),
  `app/models/concerns/captain_featurable.rb`, `lib/captain/` (base_task_service e os
  services de label/reply/rewrite/summary que o resto do app usa via ruby_llm).
  Renomear com cuidado: **Zeitwerk exige arquivo e constante casados**, e há resolução
  por string que busca-e-substitui não pega (regra do CLAUDE.md).
- **Config:** chaves `CAPTAIN_OPEN_AI_API_KEY` / `CAPTAIN_OPEN_AI_ENDPOINT` no
  `InstallationConfig` (lidas em `lib/llm/config.rb:44-48`) — migram para o esquema de
  `ai_connections` da F8, que já cobre credencial OpenAI.
- **Frontend:** `app/javascript/dashboard/routes/dashboard/captain/` e
  `components-next/captain/` → `aiAssistants/`; `store/captain/` idem;
  `featureFlags.js` e chaves I18n.
- **Feature flags:** `captain_integration`, `captain_integration_v2`,
  `captain_v1_action_classifier`, `captain_document_auto_sync`, `captain_tasks` em
  `features.yml` → uma flag própria `ai_assistants` (as demais morrem).
- **Swagger:** os JSONs em `swagger/` mencionam captain — só se edita por texto
  (regra da memória `de-chatwoot-fase3-tele`).

### Código

- **Models MIT:** `Ai::Assistant`, `Ai::AssistantVersion`, `Ai::AssistantDocument`,
  `Ai::AssistantResponse`, `Ai::AssistantInbox`.
- **`Ai::EmbeddingService`** — OpenAI `text-embedding-3-small`, resolvido por uma
  `ai_connection` de provider `openai` (a F8 já cobre a credencial).
- **`Ai::IndexDocumentJob`** (Sidekiq) — chunk → embed → grava em `ai_assistant_responses`.
- **`Ai::RetrievalService`** — busca por similaridade, top-K no prompt.

### Integração — o ponto exato

Em `Ai::AgentReplyService` (`app/services/ai/agent_reply_service.rb`), quatro pontos deixam
de ser por conta e passam a resolver o assistente por `conversation.inbox_id`:

| Hoje | Depois |
|---|---|
| `#system_prompt` monta de `custom_attributes['ai_agent_prompt']` (L263) | monta de `assistant.response_guidelines` + `guardrails` + trecho recuperado do RAG |
| `#model` lê `custom_attributes['ai_agent_model']` (L251) | `assistant.model` (validado pelo plano na F8) |
| `.inbox_allowed?` (L156) — allowlist só liga/desliga | passa a resolver **qual** assistente atende |
| `HISTORY_LIMIT` / `MAX_ITERATIONS` constantes | vêm do assistente |

**Preservar sem tocar:** `TOOL_DISCIPLINE_PROMPT` (L28) e `HANDOFF_REQUEST_REGEX` (L89) — as
duas carregam correções caras da F3a/F3b; o regex de handoff ganha os `handoff_keywords` do
assistente **como adição**, nunca como substituição.

- **Frontend:** as telas já existem (guidelines, guardrails, playground) — reaproveitar
  **depois do rename** de diretório da varredura acima (`captain/` → `aiAssistants/`),
  ligadas pela flag nova `ai_assistants`.

### Verificação
Spec de resolução de assistente por caixa; spec provando que duas caixas da mesma conta usam
prompts diferentes; spec de rollback de versão; spec de RAG com embedding stubado.

---

## F10 — Painel da agência

**Objetivo:** tirar o super admin do meio do cadastro de cliente de agência.

Não é Administrate (aquele namespace é do super admin). É um app Vue no dashboard existente,
herdando o white-label da própria agência via `Agency#apply_branding` (`agency.rb:93`).

A API já existe: `/api/v1/agencies/:id/accounts` (index, create) e `/ai_usage`
(`routes.rb:47-52`). Reusar `EnsureAgencyAccess`
(`app/controllers/concerns/ensure_agency_access.rb`) como guard.

| A agência vê | A agência nunca vê |
|---|---|
| Contas dela; criar conta (barrada por `max_client_accounts`) | Outras agências; contas sem `agency_id` |
| Distribuir `plan_allocations` entre os clientes (soma ≤ pool dela) | Conexões de IA, catálogo de modelos, preços |
| Seu white-label; consumo de IA agregado e por cliente | `InstallationConfig`, Sidekiq, super admin |

### Verificação
Spec de isolamento: agência A não enxerga nem muta nada da agência B; soma de alocações não
excede o pool.

---

## F11 — Analítica, saúde e limpeza do painel

**Saúde por conta** (`/super_admin/accounts/:id/health`) — status `ok | atenção | crítico`
por eixo: sessão Baileys (conectada/caída/QR pendente), IA (consumido vs. teto, %),
assinatura, lag do audit log. Ataca a dor real de sessão Baileys apodrecendo sozinha — ver a
queda **antes** do cliente ligar.

**Uso e custo cross-tenant** — por conta/agência: mensagens, invocações, tokens, **custo em
centavos**, conversas + séries diárias. Custo de IA por conta é o número de margem.

**Dashboard inicial** — hoje conta conversas, usuários e caixas
(`dashboard_controller.rb:5-9`). Somar: MRR, contas por plano, custo de IA do mês, margem.

**Limpeza (fazer junto, é barato):** o `AccountDashboard` (`account_dashboard.rb:11-26`)
referencia `AccountLimitsField`, `AccountFeaturesField` e `CaptainModelOverridesField` —
**três classes que não existem mais no repo**. Hoje o guard `HdevApp.enterprise?` é `false` e
nada quebra; se um dia existir um diretório `enterprise/`, o painel morre com `NameError`.
Mesmo caso em `super_admin/accounts_controller.rb:36-42`.

**Rastreamento do site de venda** — UTM na URL de checkout → `Subscription` → conta criada.
Dá atribuição de origem sem instalar nada. Ferramenta de analytics de produto é decisão
separada e não bloqueia.

---

## Ordem e dependências

```
F6  planos + limites          ← desbloqueador, nada acima funciona sem
 └─ F7  Stripe                ← fecha o ciclo do dinheiro
     └─ F7.5 quota atômica    ← independente, pode entrar em paralelo
         └─ F8  conexões IA + catálogo + gate
             └─ F9  cérebro por caixa (depende do modelo estar gateado)
                 └─ F10 painel da agência
                     └─ F11 analítica + saúde + limpeza
```

F7.5 não depende de nada e pode ser feita a qualquer momento se quiser um ganho rápido.

---

## Verificação — como provar cada fase neste ambiente

Restrições reais do workspace (do `CLAUDE.md`): **Ruby e Docker não rodam nesta máquina.**

| Nível | Como |
|---|---|
| **JS** (F8 UI, F9 frontend, F10 painel) | Local: `corepack pnpm exec vitest run <caminho>` e `corepack pnpm exec eslint --fix <caminho>`. Fecha em segundos — rodar **antes** de empurrar. |
| **Ruby** (todo o resto) | Só no CI, no espelho público `solutionshdev-sudo/hdev-crm-ci`. Montar o commit com `scripts/sync-ci-mirror.sh` e o Harvey dá o push, conferindo `git log --oneline -1` antes. Iterar num arquivo só com `workflow_dispatch` + `spec_path`. |
| **Schema** | Toda fase com migration: baixar o artifact `schema` do CI e commitar o `db/schema.rb` regenerado. O workflow não escreve na `main`. |
| **Produto** | Migration aplicada e comportamento real: só o terminal do container no EasyPanel. |

**Gate por fase:** suíte verde no CI (hoje ~6257 exemplos, 15–18 min) + os specs novos da
fase. Um `cancelled` no histórico quase sempre é o `cancel-in-progress`, não falha — olhar a
duração antes de concluir qualquer coisa.

---

## O que este plano deliberadamente **não** traz do Deskcomm

| Descartado | Motivo |
|---|---|
| RLS no Postgres | O Chatwoot inteiro assume scoping em Ruby. Trocar é reescrever a camada de acesso — risco alto, ganho zero para este modelo. |
| Vercel AI Gateway | Resolveria multi-provider de uma vez, mas põe intermediário no caminho do custo. O objetivo do Bedrock é justamente controlar billing. |
| Event log + workers próprios | Sidekiq já resolve. |
| `*_versions/*_pointers` em tudo | Adotar só onde o cliente edita algo que o agente consome: assistente (F9). O resto é over-engineering neste estágio. |
| Flywheel, intent router, skills marketplace | Bons, mas dependem de volume de operação que ainda não existe. Reavaliar depois da F11. |
