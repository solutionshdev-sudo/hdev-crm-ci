# F8 — Conexões de IA, catálogo e gate por plano (design)

Data: 2026-08-06. Aprovado em conversa com o Harvey.
Referência: `plano-fases-6-11.md` §F8. Tem 4 migrations — baixar o artifact
`schema` do CI verde e commitar o `db/schema.rb`.

## Objetivo

O modelo de IA deixa de ser string livre em `custom_attributes`. O super admin
passa a controlar provider, modalidade (API direta / Bedrock; Vertex declarado
mas sem client ainda), preço versionado e **quem pode usar o quê** — hoje
qualquer conta troca `ai_agent_model` por um modelo 5× mais caro e ninguém
impede.

## Decisões do Harvey (2026-08-06)

1. **Gate estrito + seed.** `plan_ai_models` vazio = plano não libera modelo
   nenhum. A migration seeda TODOS os planos existentes com TODOS os modelos
   do catálogo (zero mudança de comportamento no deploy); daí em diante o
   super admin remove o que não quer de cada plano.
2. **Runtime degrada, salvar recusa.** No `#update` do controller, modelo fora
   do plano = 422 (chave I18n en+pt_BR). No `raw_chat`, modelo salvo que o
   plano não libera → resolver cai pro modelo default liberado do plano +
   `Rails.logger.warn`; se o plano não libera NADA, `Ai::ModelNotAllowedError`
   e a IA fica muda (estrito é estrito).
3. **Credencial é assunto exclusivo do super admin.** Cliente nenhum (agência
   ou conta direta) vê ou cadastra API key — a IA é fornecida pela plataforma.
   As chaves de todos os providers vivem em `/super_admin/ai_connections`.
   Transição: `api_key` da conexão é nullable; enquanto o Harvey não cadastra
   a chave pelo painel, `resolved_api_key` cai no
   `GlobalConfigService.load('ANTHROPIC_API_KEY')` atual (env do servidor) —
   deploy não move segredo e a IA não para. Chave cadastrada vence a env.

## 1. Schema (4 migrations)

### `create_ai_connections`

```
provider    integer enum (anthropic: 0, openai: 1, google: 2), null: false
modality    integer enum (direct: 0, bedrock: 1, vertex: 2), null: false
label       string, null: false
api_key     text (encrypted, nullable — decisão 3)
region      string
aws_access_key_id      text (encrypted, p/ bedrock)
aws_secret_access_key  text (encrypted, p/ bedrock)
validated_at datetime · validation_error string
models_available jsonb default '{}'
active      boolean default true, null: false
unique (provider, modality, label)
```

Criptografia no padrão do repo: `encrypts :api_key, :aws_access_key_id,
:aws_secret_access_key if HdevCrm.encryption_configured?` (igual
`channel/telegram.rb:21`). Specs usam o shared example
`spec/support/examples/encrypted_external_credential_examples.rb`.

Seed (mesma migration, guarda de idempotência): uma conexão
`(anthropic, direct, 'Anthropic API')`, `api_key` nula.

### `create_ai_models`

```
canonical_id      string, null: false, unique   # "claude-haiku-4-5" — UI + AiUsageEvent
provider_model_id string, null: false            # o que vai no wire ("anthropic.claude-…" no Bedrock)
ai_connection_id  references, null: false
display_name      string, null: false
description       string
context_window    integer
supports_tools    boolean default true, null: false
default_for_provider boolean default false, null: false
deprecated_at     datetime
```

Seed: os 8 modelos de `Ai::Pricing::PRICES` (`lib/ai/pricing.rb:6`),
`provider_model_id = canonical_id` (modality direct),
`default_for_provider: true` no `claude-haiku-4-5` (é o `DEFAULT_MODEL` do
`AnthropicService`). A separação canonical/provider é o que faz Bedrock ser
troca de conexão + update de `provider_model_id`, sem tocar em conta nenhuma.

### `create_ai_model_prices`

```
ai_model_id references, null: false
input_cents_per_million     integer, null: false
output_cents_per_million    integer, null: false
embedding_cents_per_million integer
effective_from datetime, null: false
superseded_at  datetime                # NULL = preço vigente
index (ai_model_id, superseded_at)
```

Seed espelhando `PRICES` (US$/1M × 100 = cents/1M: opus 5 → 500/2500).
Trocar preço = marcar `superseded_at` + inserir linha nova, nunca update —
`AiUsageEvent` antigo mantém o custo da época.

### `create_plan_ai_models`

```
plan_id / ai_model_id references, null: false
unique (plan_id, ai_model_id)
```

Seed (decisão 1): produto cartesiano planos existentes × modelos do catálogo.

## 2. `Ai::ModelResolver`

```ruby
Ai::ModelResolver.new(account: account).resolve!(canonical_id)
# => Resolution = Struct(model:, connection:, provider_model_id:)
# raise Ai::ModelNotAllowedError se o plano não libera modelo nenhum
```

Passos:
1. **Catálogo:** `AiModel` ativo (sem `deprecated_at`) pelo `canonical_id`;
   não achou (string herdada inválida) → default do provider + log.
2. **Gate:** plano da conta pela cadeia `account.subscription.plan →
   account.agency.subscription.plan → nil` (via `grants_plan?`, como o
   `Plan::LimitEnforcer`; `plan_allocations` NÃO participa — modelo não é
   quantidade). Plano `nil` = sem gate (grandfathering, "nil = ilimitado").
   Plano presente e modelo fora do join → fallback pro default liberado
   (decisão 2: `default_for_provider` liberado, senão o mais barato liberado
   pelo preço vigente) + warn; plano sem NENHUM modelo → raise.
3. **Conexão:** a `ai_connection` do modelo precisa estar `active`;
   `resolved_api_key` = chave cifrada da conexão OU fallback GlobalConfig
   (decisão 3, só provider anthropic + direct).

`#allowed_models` (mesma classe) devolve a lista gateada — usada pelo
endpoint da UI e pela validação do controller (uma fonte só).

## 3. `Ai::AnthropicService` — client injetado

`#client` deixa de construir fixo:

- `direct` → `Anthropic::Client.new(api_key: connection.resolved_api_key)`
- `bedrock` → `Anthropic::BedrockMantleClient.new(aws_region: connection.region)`
  com as credenciais AWS da conexão no ambiente do processo
- `vertex` → enum existe, client fica pra quando houver conexão google
  (YAGNI; o SDK tem `Anthropic::VertexClient`)

`raw_chat` resolve **a cada chamada** (é o gate de execução — downgrade de
plano com modelo caro salvo em `custom_attributes` é interceptado aqui) e usa
`resolution.provider_model_id` no wire. `AiUsageEvent.record!` grava
`resolution.model.canonical_id` — custo e UI estáveis entre modalidades.
`CopilotService::MODEL` passa pelo resolver igual.

Antes de codar o client Bedrock: conferir a doc oficial do gem `anthropic`
(WebFetch) — regra da F7, não chutar assinatura.

## 4. `Ai::Pricing` lê da tabela

`Ai::Pricing.cost(canonical_id, input, output)` mantém assinatura
(`AiUsageEvent#compute_totals` intocado). Novo interior: preço vigente
(`superseded_at IS NULL`) por `canonical_id`, cache em memória de 5 min
(memoização com TTL — sem dependência de Rails.cache/Redis no hot path),
custo arredondado **para cima** na 8ª casa (errar a favor da cobrança).
Modelo fora da tabela → `DEFAULT` atual (nunca custo zero). A constante
`PRICES` vira só semente da migration e some do runtime.

## 5. Gates e UI

- **`ai_agents_controller#update`:** `ai_agent_model` fora de
  `allowed_models` → 422 com `errors.ai_agents.model_not_in_plan`
  (en + pt_BR).
- **Endpoint novo** `GET /api/v1/accounts/:id/ai_agents/models` →
  `[{canonical_id, display_name, default}]` filtrado pelo plano.
- **`aiAgent/Index.vue`:** `MODEL_OPTIONS` hardcoded morre; busca do endpoint
  (vitest local antes de empurrar).
- **Dashboards:** `AiConnectionDashboard` (chave NUNCA exposta — form
  write-only, show mostra só últimos 4), `AiModelDashboard`,
  `AiModelPriceDashboard`; `PlanDashboard` ganha o has_many de `ai_models`.
  Rotas no namespace `:super_admin`.

## 6. O que NÃO muda nesta fase

- `custom_attributes['ai_agent_model']` continua sendo onde a escolha vive
  (a F9 move pro assistente por caixa).
- `CAPTAIN_OPEN_AI_*` / ruby_llm / `lib/llm/config.rb` — migram na F9 junto
  do rename (plano §F9).
- Validação ativa de credencial (`validated_at`/`validation_error` ficam no
  schema, botão de "testar conexão" pode vir depois) — YAGNI agora.

## Verificação (CI do espelho)

1. Resolver: cadeia completa (direto, agência, sem plano), fallback de
   downgrade com warn, raise com plano zerado, deprecated → default.
2. Gate nas duas pontas: 422 no controller E fallback no service.
3. Criptografia: shared example nas 3 colunas; chave ausente de
   serialização/log (spec de dashboard/serializer).
4. Pricing: preço vigente vs superseded, cache (TTL stubado), arredondamento
   pra cima, fallback DEFAULT.
5. Seeds: migration em banco com planos/contas de teste → todo plano ganha
   todos os modelos; conexão seedada resolve via GlobalConfig.
6. Vitest no `Index.vue` novo; eslint local.
7. Suíte inteira verde + artifact `schema` commitado.

## Adendo: bootstrap após `schema:load`

O CI prepara o banco com `db:schema:load db:migrate`. Quando o `schema.rb`
já inclui as tabelas da F8, o DML das migrations antigas não é executado e
o banco pode nascer sem conexão, modelos, preços ou vínculos por plano.

`Ai::CatalogBootstrap.run!` roda ao final de `db:migrate` quando todas as
tabelas necessárias existem. Em um banco sem dados da F8, ele cria a conexão
Anthropic padrão, os oito modelos, seus preços iniciais e o produto cartesiano
de planos e modelos.

O bootstrap é conservador em bancos já administrados:

- modelos existentes mantêm conexão, `provider_model_id`, nome e default;
- modelos com preço vigente mantêm esse preço;
- vínculos por plano só recebem o seed inicial quando a tabela inteira está
  vazia, preservando remoções feitas pelo super admin;
- execuções repetidas não criam duplicatas.

Os specs devem cobrir os dois limites: reconstrução completa em banco vazio
e preservação de customizações em banco populado.
