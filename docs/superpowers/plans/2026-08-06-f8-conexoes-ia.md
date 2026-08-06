# F8 — Conexões de IA, catálogo e gate por plano — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modelo de IA deixa de ser string livre: catálogo global curado (`ai_models`), credenciais só no super admin (`ai_connections`), preço versionado (`ai_model_prices`) e gate por plano (`plan_ai_models`) aplicado no salvar E no executar.

**Architecture:** `Ai::ModelResolver` é a única fonte de "que modelo essa conta pode usar": resolve `canonical_id` → `(connection, provider_model_id)` validando o plano pela cadeia `subscription → agency.subscription → nil`. `AnthropicService` recebe o client construído a partir da conexão (direct/bedrock). `Ai::Pricing` troca a constante por leitura da tabela com cache de 5 min. Spec: `docs/superpowers/specs/2026-08-06-f8-conexoes-ia-design.md`.

**Tech Stack:** Rails 7.1, Administrate (super admin), gem oficial `anthropic`, Vue 3 + vitest (UI), FactoryBot/RSpec.

## Global Constraints

- **Ruby NÃO roda nesta máquina.** Steps "rode o teste" de Ruby são "escreva e siga"; a rodada vermelho→verde acontece no CI do espelho (Task 10). **JS roda local**: `corepack pnpm exec vitest run <caminho>` e `corepack pnpm exec eslint --fix <caminho>` ANTES de empurrar (Task 8).
- Decisões do Harvey (design doc): gate **estrito + seed** (join vazio = nada liberado; migration seeda todos os planos × todos os modelos); runtime **degrada com log** (default liberado do plano; plano zerado = raise); **credencial só no super admin**, `api_key` nullable com fallback `GlobalConfigService.load('ANTHROPIC_API_KEY')` (provider anthropic + direct).
- Texto visível ao usuário = chave I18n em `en` **E** `pt_BR` (`api_errors.*.yml`); o inglês precisa bater com o que os specs assertam.
- Criptografia: `encrypts ... if HdevCrm.encryption_configured?` + shared example `spec/support/examples/encrypted_external_credential_examples.rb`.
- `find_or_create_by!` + rescue `RecordNotUnique` quando houver corrida; **nunca** `create_or_find_by!`.
- Seeds de migration em **SQL puro** (nunca via model — Zeitwerk/validações mudam; e nenhum seed grava valor cifrado: a conexão nasce com `api_key` NULL).
- API de gem: **conferir doc oficial via WebFetch antes de escrever** (client Bedrock, Task 6) — armadilha da F7.
- Armadilhas rubocop conhecidas: `Style/ClassAndModuleChildren` compact em classe nova; `Layout/HashAlignment` em kwargs multi-linha; `Metrics/MethodLength` máx 19; `RSpec/ContextWording`.
- `db/schema.rb` vem do artifact `schema` do CI verde — nunca à mão.
- Branch: `feat/f8-conexoes-ia` a partir da `main`.
- Migration timestamps: `20260806000002` a `20260806000005` (o `...000001` é da F7.5).

---

### Task 0: Branch

- [ ] **Step 1:**

```bash
cd "c:/Users/hdev/Downloads/backup-20260723T235954Z-1-001/backup/Hdev-CRM"
git checkout main && git pull -q origin main && git checkout -b feat/f8-conexoes-ia
```

---

### Task 1: `ai_connections` — migration, model, factory, spec

**Files:**
- Create: `hdevCRM/db/migrate/20260806000002_create_ai_connections.rb`
- Create: `hdevCRM/app/models/ai_connection.rb`
- Create: `hdevCRM/spec/factories/ai_connections.rb`
- Create: `hdevCRM/spec/models/ai_connection_spec.rb`

**Interfaces:**
- Produces: `AiConnection` com enums `provider` (`anthropic|openai|google`, prefixo `provider_`) e `modality` (`direct|bedrock|vertex`, prefixo `modality_`), scope `.enabled`, `#resolved_api_key` (String|nil), `#masked_api_key` (String). Uma conexão seedada `(anthropic, direct, 'Anthropic API')` com `api_key` NULL.

- [ ] **Step 1: Migration**

```ruby
class CreateAiConnections < ActiveRecord::Migration[7.1]
  # F8: credencial de IA é assunto exclusivo do super admin. api_key nasce
  # NULL de propósito — enquanto o painel não recebe a chave, o runtime cai
  # no GlobalConfigService (ANTHROPIC_API_KEY da env), então o deploy não
  # move segredo e a IA não para (design doc, decisão 3).
  def up
    create_table :ai_connections do |t|
      t.integer :provider, null: false, default: 0
      t.integer :modality, null: false, default: 0
      t.string :label, null: false
      t.text :api_key
      t.string :region
      t.text :aws_access_key_id
      t.text :aws_secret_access_key
      t.datetime :validated_at
      t.string :validation_error
      t.jsonb :models_available, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :ai_connections, [:provider, :modality, :label], unique: true

    execute <<~SQL.squish
      INSERT INTO ai_connections (provider, modality, label, created_at, updated_at)
      VALUES (0, 0, 'Anthropic API', NOW(), NOW())
    SQL
  end

  def down
    drop_table :ai_connections
  end
end
```

- [ ] **Step 2: Spec**

```ruby
require 'rails_helper'

RSpec.describe AiConnection do
  describe 'validations' do
    it 'rejects a duplicate (provider, modality, label) triple' do
      create(:ai_connection, label: 'Principal')
      expect(build(:ai_connection, label: 'Principal')).not_to be_valid
    end
  end

  it_behaves_like 'encrypted external credential', factory: :ai_connection, attribute: :api_key
  it_behaves_like 'encrypted external credential', factory: :ai_connection, attribute: :aws_secret_access_key

  describe '#resolved_api_key' do
    it 'prefers the key stored on the connection' do
      connection = create(:ai_connection, api_key: 'sk-painel')
      expect(connection.resolved_api_key).to eq('sk-painel')
    end

    it 'falls back to the global ANTHROPIC_API_KEY for anthropic/direct' do
      allow(GlobalConfigService).to receive(:load).with('ANTHROPIC_API_KEY', nil).and_return('sk-env')
      connection = create(:ai_connection, api_key: nil)
      expect(connection.resolved_api_key).to eq('sk-env')
    end

    it 'has no fallback for other providers' do
      connection = create(:ai_connection, provider: 'openai', api_key: nil)
      expect(connection.resolved_api_key).to be_nil
    end
  end

  describe '#masked_api_key' do
    it 'shows only the last four characters' do
      connection = create(:ai_connection, api_key: 'sk-abcdef1234')
      expect(connection.masked_api_key).to eq('••••1234')
      expect(connection.masked_api_key).not_to include('abcdef')
    end

    it 'is a dash when the key is absent' do
      expect(build(:ai_connection, api_key: nil).masked_api_key).to eq('—')
    end
  end
end
```

- [ ] **Step 3: Factory**

```ruby
# frozen_string_literal: true

FactoryBot.define do
  factory :ai_connection do
    provider { 'anthropic' }
    modality { 'direct' }
    sequence(:label) { |n| "Conexão #{n}" }
    active { true }
  end
end
```

- [ ] **Step 4: Model**

```ruby
class AiConnection < ApplicationRecord
  # TODO: Remove guard once encryption keys become mandatory (mesmo padrão de channel/telegram.rb).
  encrypts :api_key, :aws_access_key_id, :aws_secret_access_key if HdevCrm.encryption_configured?

  enum :provider, { anthropic: 0, openai: 1, google: 2 }, prefix: :provider
  enum :modality, { direct: 0, bedrock: 1, vertex: 2 }, prefix: :modality

  has_many :ai_models, dependent: :restrict_with_error

  validates :label, presence: true, uniqueness: { scope: [:provider, :modality] }

  scope :enabled, -> { where(active: true) }

  # Decisão 3 do design: chave do painel vence; sem chave, a conexão seedada
  # (anthropic/direct) cai na env que já roda em produção hoje.
  def resolved_api_key
    return api_key if api_key.present?
    return GlobalConfigService.load('ANTHROPIC_API_KEY', nil) if provider_anthropic? && modality_direct?

    nil
  end

  def masked_api_key
    return '—' if api_key.blank?

    "••••#{api_key.last(4)}"
  end
end
```

- [ ] **Step 5: Commit**

```bash
git add hdevCRM/db/migrate/20260806000002_create_ai_connections.rb hdevCRM/app/models/ai_connection.rb hdevCRM/spec/factories/ai_connections.rb hdevCRM/spec/models/ai_connection_spec.rb
git commit -m "F8: ai_connections cifrada com fallback de chave pro GlobalConfig"
```

---

### Task 2: `ai_models` — migration com seed, model, factory, spec

**Files:**
- Create: `hdevCRM/db/migrate/20260806000003_create_ai_models.rb`
- Create: `hdevCRM/app/models/ai_model.rb`
- Create: `hdevCRM/spec/factories/ai_models.rb`
- Create: `hdevCRM/spec/models/ai_model_spec.rb`

**Interfaces:**
- Consumes: `AiConnection` (Task 1); a conexão seedada `label = 'Anthropic API'`.
- Produces: `AiModel` com `belongs_to :ai_connection`, scope `.live` (sem `deprecated_at`), `#current_price` (AiModelPrice|nil — associação criada na Task 3). Catálogo seedado com os 8 canonical_ids de `Ai::Pricing::PRICES`, `default_for_provider: true` só no `claude-haiku-4-5`.

- [ ] **Step 1: Migration (seed em SQL puro, conexão achada por subselect)**

```ruby
class CreateAiModels < ActiveRecord::Migration[7.1]
  # canonical_id é o que a UI mostra e o AiUsageEvent grava; provider_model_id
  # é o que vai no wire. É essa separação que faz Bedrock ser troca de conexão
  # + update de provider_model_id, sem tocar em conta nenhuma.
  def up
    create_table :ai_models do |t|
      t.string :canonical_id, null: false
      t.string :provider_model_id, null: false
      t.references :ai_connection, null: false, foreign_key: true
      t.string :display_name, null: false
      t.string :description
      t.integer :context_window
      t.boolean :supports_tools, null: false, default: true
      t.boolean :default_for_provider, null: false, default: false
      t.datetime :deprecated_at
      t.timestamps
    end
    add_index :ai_models, :canonical_id, unique: true

    seed_catalog
  end

  def down
    drop_table :ai_models
  end

  private

  # Os 8 modelos da constante Ai::Pricing::PRICES (lib/ai/pricing.rb) em
  # 06/08/2026. Modality direct: provider_model_id == canonical_id.
  CATALOG = [
    ['claude-fable-5',    'Claude Fable 5',    false],
    ['claude-opus-5',     'Claude Opus 5',     false],
    ['claude-opus-4-8',   'Claude Opus 4.8',   false],
    ['claude-opus-4-7',   'Claude Opus 4.7',   false],
    ['claude-opus-4-6',   'Claude Opus 4.6',   false],
    ['claude-sonnet-5',   'Claude Sonnet 5',   false],
    ['claude-sonnet-4-6', 'Claude Sonnet 4.6', false],
    ['claude-haiku-4-5',  'Claude Haiku 4.5',  true]
  ].freeze

  def seed_catalog
    CATALOG.each do |canonical, display, default|
      execute <<~SQL.squish
        INSERT INTO ai_models
          (canonical_id, provider_model_id, ai_connection_id, display_name, default_for_provider, created_at, updated_at)
        SELECT '#{canonical}', '#{canonical}', id, '#{display}', #{default}, NOW(), NOW()
        FROM ai_connections WHERE provider = 0 AND modality = 0 AND label = 'Anthropic API'
      SQL
    end
  end
end
```

- [ ] **Step 2: Spec**

```ruby
require 'rails_helper'

RSpec.describe AiModel do
  describe 'validations' do
    it 'rejects a duplicate canonical_id' do
      create(:ai_model, canonical_id: 'modelo-x')
      expect(build(:ai_model, canonical_id: 'modelo-x')).not_to be_valid
    end
  end

  describe '.live' do
    it 'excludes deprecated models' do
      live = create(:ai_model)
      create(:ai_model, deprecated_at: 1.day.ago)
      expect(described_class.live.where(id: [live.id])).to contain_exactly(live)
    end
  end

  describe 'seed da migration' do
    it 'contains the 8 models from the old PRICES constant, haiku as default' do
      seeded = described_class.where(canonical_id: %w[claude-fable-5 claude-opus-5 claude-opus-4-8
                                                      claude-opus-4-7 claude-opus-4-6 claude-sonnet-5
                                                      claude-sonnet-4-6 claude-haiku-4-5])
      expect(seeded.count).to eq(8)
      expect(seeded.find_by(default_for_provider: true).canonical_id).to eq('claude-haiku-4-5')
    end
  end
end
```

- [ ] **Step 3: Factory** (canonical_id com sequência pra nunca colidir com o seed)

```ruby
# frozen_string_literal: true

FactoryBot.define do
  factory :ai_model do
    ai_connection
    sequence(:canonical_id) { |n| "modelo-teste-#{n}" }
    provider_model_id { canonical_id }
    display_name { "Modelo #{canonical_id}" }
  end
end
```

- [ ] **Step 4: Model**

```ruby
class AiModel < ApplicationRecord
  belongs_to :ai_connection
  has_many :plan_ai_models, dependent: :destroy
  has_many :plans, through: :plan_ai_models

  validates :canonical_id, presence: true, uniqueness: true
  validates :provider_model_id, :display_name, presence: true

  scope :live, -> { where(deprecated_at: nil) }

  def current_price
    ai_model_prices.find_by(superseded_at: nil)
  end
end
```

(`has_many :ai_model_prices` entra na Task 3; `plan_ai_models` referencia a Task 4 — se o Zeitwerk reclamar na ordem de execução, declare as associações na task que cria a tabela correspondente.)

**Ordem prática:** como as associações cruzam tasks, o commit desta task pode declarar só `belongs_to :ai_connection` + validações + scope, e as `has_many` entram nas Tasks 3/4 junto das tabelas.

- [ ] **Step 5: Commit**

```bash
git add hdevCRM/db/migrate/20260806000003_create_ai_models.rb hdevCRM/app/models/ai_model.rb hdevCRM/spec/factories/ai_models.rb hdevCRM/spec/models/ai_model_spec.rb
git commit -m "F8: catalogo ai_models seedado a partir da constante de precos"
```

---

### Task 3: `ai_model_prices` + `Ai::Pricing` lendo da tabela

**Files:**
- Create: `hdevCRM/db/migrate/20260806000004_create_ai_model_prices.rb`
- Create: `hdevCRM/app/models/ai_model_price.rb`
- Create: `hdevCRM/spec/factories/ai_model_prices.rb`
- Modify: `hdevCRM/app/models/ai_model.rb` (adicionar `has_many :ai_model_prices, dependent: :destroy` e o `#current_price` se ficou de fora)
- Modify: `hdevCRM/lib/ai/pricing.rb` (reescrita interna, assinaturas mantidas)
- Modify: `hdevCRM/spec/lib/ai/pricing_spec.rb` (adicionar casos novos; os existentes continuam valendo porque o seed espelha a constante)

**Interfaces:**
- Consumes: `AiModel` (Task 2) e o catálogo seedado.
- Produces: `AiModelPrice` (`superseded_at` NULL = vigente); `Ai::Pricing.for_model(model)` → `{input:, output:}` USD/1M (shape atual), `Ai::Pricing.cost(model, in, out)` → Float USD (assinatura atual — `AiUsageEvent#compute_totals` intocado), `Ai::Pricing.reset_cache!`.

- [ ] **Step 1: Migration com seed (cents inteiros = USD × 100)**

```ruby
class CreateAiModelPrices < ActiveRecord::Migration[7.1]
  # Preço versionado: trocar preço = marcar superseded_at + inserir linha
  # nova, nunca update — AiUsageEvent antigo mantém o custo da época.
  # Cents inteiros por 1M de tokens: o custo vira múltiplo exato de 1e-8 USD.
  def up
    create_table :ai_model_prices do |t|
      t.references :ai_model, null: false, foreign_key: true
      t.integer :input_cents_per_million, null: false
      t.integer :output_cents_per_million, null: false
      t.integer :embedding_cents_per_million
      t.datetime :effective_from, null: false
      t.datetime :superseded_at
      t.timestamps
    end
    add_index :ai_model_prices, [:ai_model_id, :superseded_at]

    seed_prices
  end

  def down
    drop_table :ai_model_prices
  end

  private

  # USD/1M da constante Ai::Pricing::PRICES → cents/1M.
  PRICES_CENTS = {
    'claude-fable-5' => [1000, 5000],
    'claude-opus-5' => [500, 2500],
    'claude-opus-4-8' => [500, 2500],
    'claude-opus-4-7' => [500, 2500],
    'claude-opus-4-6' => [500, 2500],
    'claude-sonnet-5' => [300, 1500],
    'claude-sonnet-4-6' => [300, 1500],
    'claude-haiku-4-5' => [100, 500]
  }.freeze

  def seed_prices
    PRICES_CENTS.each do |canonical, (input_cents, output_cents)|
      execute <<~SQL.squish
        INSERT INTO ai_model_prices
          (ai_model_id, input_cents_per_million, output_cents_per_million, effective_from, created_at, updated_at)
        SELECT id, #{input_cents}, #{output_cents}, NOW(), NOW(), NOW()
        FROM ai_models WHERE canonical_id = '#{canonical}'
      SQL
    end
  end
end
```

- [ ] **Step 2: Model + factory**

```ruby
class AiModelPrice < ApplicationRecord
  belongs_to :ai_model

  validates :input_cents_per_million, :output_cents_per_million,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :effective_from, presence: true

  scope :current, -> { where(superseded_at: nil) }
end
```

```ruby
# frozen_string_literal: true

FactoryBot.define do
  factory :ai_model_price do
    ai_model
    input_cents_per_million { 500 }
    output_cents_per_million { 2500 }
    effective_from { Time.zone.now }
  end
end
```

- [ ] **Step 3: Specs novos no `pricing_spec.rb`** (os `describe` existentes ficam — o seed espelha a constante, então continuam verdes)

```ruby
  describe 'DB-backed prices (F8)' do
    after { described_class.reset_cache! }

    it 'reads the current price row for a catalog model' do
      model = create(:ai_model)
      create(:ai_model_price, ai_model: model, input_cents_per_million: 700, output_cents_per_million: 1400)
      described_class.reset_cache!

      expect(described_class.for_model(model.canonical_id)).to eq(input: 7.0, output: 14.0)
      expect(described_class.cost(model.canonical_id, 1_000_000, 1_000_000)).to eq(21.0)
    end

    it 'ignores superseded rows' do
      model = create(:ai_model)
      create(:ai_model_price, ai_model: model, input_cents_per_million: 100, output_cents_per_million: 100,
                              superseded_at: 1.hour.ago)
      create(:ai_model_price, ai_model: model, input_cents_per_million: 900, output_cents_per_million: 900)
      described_class.reset_cache!

      expect(described_class.for_model(model.canonical_id)).to eq(input: 9.0, output: 9.0)
    end

    it 'caches lookups for five minutes' do
      model = create(:ai_model)
      create(:ai_model_price, ai_model: model, input_cents_per_million: 100, output_cents_per_million: 500)
      described_class.reset_cache!
      described_class.for_model(model.canonical_id)

      expect(AiModelPrice).not_to receive(:joins)
      described_class.for_model(model.canonical_id)
    end
  end
```

- [ ] **Step 4: Reescrever `lib/ai/pricing.rb`**

```ruby
module Ai
  # Preço vem de ai_model_prices (linha vigente = superseded_at IS NULL) com
  # cache em memória de 5 min — compute_totals roda a cada AiUsageEvent e não
  # pode custar um SELECT por evento. Modelo fora do catálogo cai no DEFAULT
  # (nunca gravar custo zero). A antiga constante PRICES virou seed de
  # migration (20260806000004) e saiu do runtime.
  class Pricing
    DEFAULT = { input: 5.0, output: 25.0 }.freeze
    CACHE_TTL = 5.minutes

    class << self
      def for_model(model)
        cents = cents_for(model)
        { input: cents[:input] / 100.0, output: cents[:output] / 100.0 }
      end

      def cost(model, input_tokens, output_tokens)
        cents = cents_for(model)
        total_cents_per_million = (input_tokens.to_i * cents[:input]) + (output_tokens.to_i * cents[:output])
        total_cents_per_million / 100_000_000.0
      end

      # Specs e troca de preço pelo painel derrubam o cache do processo.
      def reset_cache!
        @cache = {}
      end

      private

      def cents_for(model)
        @cache ||= {}
        entry = @cache[model.to_s]
        return entry[:value] if entry && entry[:at] > CACHE_TTL.ago

        value = lookup(model.to_s) || { input: (DEFAULT[:input] * 100).to_i, output: (DEFAULT[:output] * 100).to_i }
        @cache[model.to_s] = { value: value, at: Time.zone.now }
        value
      end

      def lookup(canonical_id)
        price = AiModelPrice.joins(:ai_model)
                            .where(ai_models: { canonical_id: canonical_id }, superseded_at: nil)
                            .order(effective_from: :desc)
                            .first
        return nil if price.blank?

        { input: price.input_cents_per_million, output: price.output_cents_per_million }
      end
    end
  end
end
```

- [ ] **Step 5: Commit**

```bash
git add hdevCRM/db/migrate/20260806000004_create_ai_model_prices.rb hdevCRM/app/models/ai_model_price.rb hdevCRM/app/models/ai_model.rb hdevCRM/spec/factories/ai_model_prices.rb hdevCRM/lib/ai/pricing.rb hdevCRM/spec/lib/ai/pricing_spec.rb
git commit -m "F8: preco versionado em ai_model_prices; Pricing le da tabela com cache"
```

---

### Task 4: `plan_ai_models` — o gate, com seed cartesiano

**Files:**
- Create: `hdevCRM/db/migrate/20260806000005_create_plan_ai_models.rb`
- Create: `hdevCRM/app/models/plan_ai_model.rb`
- Modify: `hdevCRM/app/models/plan.rb` (associações)
- Create: `hdevCRM/spec/models/plan_ai_model_spec.rb`

**Interfaces:**
- Consumes: `Plan` (existente), `AiModel` (Task 2).
- Produces: `PlanAiModel`; `Plan#ai_models` / `Plan#ai_model_ids=` (usados pelo resolver na Task 5 e pelo form do Administrate na Task 9).

- [ ] **Step 1: Migration**

```ruby
class CreatePlanAiModels < ActiveRecord::Migration[7.1]
  # Decisão 1 do design (gate estrito + seed): join vazio = plano não libera
  # modelo nenhum. Pra nenhum plano existente mudar de comportamento no
  # deploy, todo plano nasce liberando o catálogo inteiro — o super admin
  # remove o que não quer depois.
  def up
    create_table :plan_ai_models do |t|
      t.references :plan, null: false, foreign_key: true
      t.references :ai_model, null: false, foreign_key: true
      t.timestamps
    end
    add_index :plan_ai_models, [:plan_id, :ai_model_id], unique: true

    execute <<~SQL.squish
      INSERT INTO plan_ai_models (plan_id, ai_model_id, created_at, updated_at)
      SELECT plans.id, ai_models.id, NOW(), NOW() FROM plans CROSS JOIN ai_models
    SQL
  end

  def down
    drop_table :plan_ai_models
  end
end
```

- [ ] **Step 2: Model + associações no Plan**

```ruby
class PlanAiModel < ApplicationRecord
  belongs_to :plan
  belongs_to :ai_model

  validates :ai_model_id, uniqueness: { scope: :plan_id }
end
```

No `plan.rb`, junto de `has_many :subscriptions`:

```ruby
  has_many :plan_ai_models, dependent: :destroy
  has_many :ai_models, through: :plan_ai_models
```

- [ ] **Step 3: Spec**

```ruby
require 'rails_helper'

RSpec.describe PlanAiModel do
  it 'rejects the same model twice in a plan' do
    plan = create(:plan)
    model = create(:ai_model)
    create(:plan_ai_model, plan: plan, ai_model: model)

    expect(build(:plan_ai_model, plan: plan, ai_model: model)).not_to be_valid
  end

  it 'lets the plan manage the join through ai_model_ids' do
    plan = create(:plan)
    model = create(:ai_model)

    plan.update!(ai_model_ids: [model.id])

    expect(plan.reload.ai_models).to contain_exactly(model)
  end
end
```

Factory (dentro de `spec/factories/ai_models.rb` ou arquivo próprio):

```ruby
  factory :plan_ai_model do
    plan
    ai_model
  end
```

**Nota de verificação:** o seed cartesiano NÃO é testável no CI — o banco de
teste migra antes de qualquer plano existir, então o CROSS JOIN insere zero
linhas lá. A prova é em produção, no deploy (terminal EasyPanel):
`SELECT count(*) FROM plan_ai_models;` deve ser `count(plans) × 8`.

- [ ] **Step 4: Commit**

```bash
git add hdevCRM/db/migrate/20260806000005_create_plan_ai_models.rb hdevCRM/app/models/plan_ai_model.rb hdevCRM/app/models/plan.rb hdevCRM/spec/models/plan_ai_model_spec.rb hdevCRM/spec/factories/ai_models.rb
git commit -m "F8: plan_ai_models e o gate por plano, seed cartesiano nos planos existentes"
```

---

### Task 5: `Ai::ModelResolver` + `Ai::ModelNotAllowedError`

**Files:**
- Create: `hdevCRM/app/services/ai/model_not_allowed_error.rb`
- Create: `hdevCRM/app/services/ai/model_resolver.rb`
- Create: `hdevCRM/spec/services/ai/model_resolver_spec.rb`

**Interfaces:**
- Consumes: `AiModel.live`, `AiConnection#enabled`/`#resolved_api_key`, `Plan#ai_models`, `Subscription#grants_plan?`.
- Produces:
  - `Ai::ModelResolver.new(account: account)`
  - `#resolve!(canonical_id)` → `Resolution` (Struct com `model:`, `connection:`, `provider_model_id:`); raise `Ai::ModelNotAllowedError` quando o plano não libera nenhum modelo ou a conexão está inativa.
  - `#allowed_models` → `ActiveRecord::Relation<AiModel>` (gateada pelo plano; sem plano = catálogo `live` inteiro).
  - `#allowed?(canonical_id)` → Boolean.

- [ ] **Step 1: Error class** — subclasse de `QuotaExceededError` DE PROPÓSITO: os três call sites que hoje resgatam quota (`agent_reply_service.rb:189`, `ai_node.rb:27`, `copilots_controller.rb:4`) passam a silenciar a IA graciosamente também quando o plano não libera modelo, sem tocar em nenhum deles.

```ruby
module Ai
  # Plano da conta não libera o modelo pedido (e nenhum fallback existe) ou a
  # conexão está desativada. Herda de QuotaExceededError de propósito: pros
  # call sites, "sem modelo liberado" e "sem tokens" têm o mesmo tratamento —
  # a IA fica muda em vez de derrubar o fluxo.
  class ModelNotAllowedError < QuotaExceededError; end
end
```

- [ ] **Step 2: Spec**

```ruby
require 'rails_helper'

RSpec.describe Ai::ModelResolver do
  let(:agency) { create(:agency) }
  let(:account) { create(:account, agency: agency) }
  let(:resolver) { described_class.new(account: account) }

  def grant_plan!(owner, *models)
    plan = create(:plan)
    plan.update!(ai_model_ids: models.map(&:id))
    create(:subscription, :active, owner: owner, plan: plan)
    plan
  end

  describe '#resolve!' do
    it 'resolves a live catalog model for an account without a plan (grandfathering)' do
      model = create(:ai_model)

      resolution = resolver.resolve!(model.canonical_id)

      expect(resolution.model).to eq(model)
      expect(resolution.connection).to eq(model.ai_connection)
      expect(resolution.provider_model_id).to eq(model.provider_model_id)
    end

    it 'uses the direct subscription plan as the gate' do
      allowed = create(:ai_model)
      blocked = create(:ai_model)
      grant_plan!(account, allowed)

      expect(resolver.resolve!(allowed.canonical_id).model).to eq(allowed)
      expect(resolver.resolve!(blocked.canonical_id).model).to eq(allowed) # degrada pro liberado
    end

    it 'falls back to the agency plan when the account has no subscription' do
      allowed = create(:ai_model)
      grant_plan!(agency, allowed)
      blocked = create(:ai_model)

      expect(resolver.resolve!(blocked.canonical_id).model).to eq(allowed)
    end

    it 'prefers the default_for_provider among the allowed models on fallback' do
      cheap = create(:ai_model, default_for_provider: true)
      other = create(:ai_model)
      blocked = create(:ai_model)
      grant_plan!(account, cheap, other)

      expect(resolver.resolve!(blocked.canonical_id).model).to eq(cheap)
    end

    it 'logs a warning when it degrades' do
      allowed = create(:ai_model)
      blocked = create(:ai_model)
      grant_plan!(account, allowed)
      allow(Rails.logger).to receive(:warn)

      resolver.resolve!(blocked.canonical_id)

      expect(Rails.logger).to have_received(:warn).with(/#{blocked.canonical_id}/)
    end

    it 'degrades an unknown canonical_id (legacy free string) to the default' do
      fallback = create(:ai_model, default_for_provider: true)
      grant_plan!(account, fallback)

      expect(resolver.resolve!('string-livre-antiga').model).to eq(fallback)
    end

    it 'skips deprecated models' do
      dead = create(:ai_model, deprecated_at: 1.day.ago)
      live = create(:ai_model, default_for_provider: true)
      grant_plan!(account, dead, live)

      expect(resolver.resolve!(dead.canonical_id).model).to eq(live)
    end

    it 'raises when the plan releases no model at all (strict gate)' do
      plan = create(:plan)
      create(:subscription, :active, owner: account, plan: plan)

      expect { resolver.resolve!('claude-haiku-4-5') }.to raise_error(Ai::ModelNotAllowedError)
    end

    it 'raises when the connection is disabled' do
      model = create(:ai_model)
      model.ai_connection.update!(active: false)

      expect { resolver.resolve!(model.canonical_id) }.to raise_error(Ai::ModelNotAllowedError)
    end

    it 'is rescuable by the existing quota rescue paths' do
      expect(Ai::ModelNotAllowedError.ancestors).to include(Ai::QuotaExceededError)
    end
  end

  describe '#allowed_models' do
    it 'returns the whole live catalog when no plan is in the chain' do
      model = create(:ai_model)
      expect(resolver.allowed_models).to include(model)
    end

    it 'returns only the plan selection when a plan exists' do
      allowed = create(:ai_model)
      create(:ai_model)
      grant_plan!(account, allowed)

      expect(resolver.allowed_models).to contain_exactly(allowed)
    end
  end
end
```

Nota: o banco de teste tem o catálogo seedado (8 modelos) — por isso os specs de conjunto usam `contain_exactly` só quando há plano (o gate filtra) e `include` quando não há.

- [ ] **Step 3: Implementação**

```ruby
module Ai
  # A única fonte de "que modelo essa conta pode usar e por qual conexão".
  #
  # Cadeia do plano (modelo NÃO é quantidade: plan_allocations não participa):
  #   account.subscription.plan (se grants_plan?)
  #     ↓ ausente
  #   account.agency.subscription.plan (se grants_plan?)
  #     ↓ ausente
  #   nil = sem gate (grandfathering, "nil = ilimitado" da F6)
  #
  # Runtime degrada (decisão 2 do design): modelo fora do plano cai pro
  # default liberado com warn — downgrade de plano não mata o bot do cliente.
  # Plano sem NENHUM modelo liberado = ModelNotAllowedError (estrito).
  class ModelResolver
    Resolution = Struct.new(:model, :connection, :provider_model_id, keyword_init: true)

    pattr_initialize [:account!]

    def resolve!(canonical_id)
      model = pick_model(canonical_id.to_s)
      connection = model.ai_connection
      raise Ai::ModelNotAllowedError, "connection #{connection.id} disabled" unless connection.active?

      Resolution.new(model: model, connection: connection, provider_model_id: model.provider_model_id)
    end

    def allowed_models
      return AiModel.live if plan.nil?

      AiModel.live.joins(:plan_ai_models).where(plan_ai_models: { plan_id: plan.id })
    end

    def allowed?(canonical_id)
      allowed_models.exists?(canonical_id: canonical_id)
    end

    private

    def pick_model(canonical_id)
      requested = AiModel.live.find_by(canonical_id: canonical_id)
      return degrade(canonical_id) if requested.nil?
      return requested if plan.nil? || allowed?(requested.canonical_id)

      degrade(canonical_id)
    end

    def degrade(canonical_id)
      fallback = default_allowed_model
      raise Ai::ModelNotAllowedError, "plan releases no AI model for account #{account.id}" if fallback.nil?

      Rails.logger.warn("Ai::ModelResolver account=#{account.id}: '#{canonical_id}' indisponível, usando '#{fallback.canonical_id}'")
      fallback
    end

    def default_allowed_model
      allowed_models.find_by(default_for_provider: true) || cheapest_allowed
    end

    # Sem default liberado, o mais barato pelo preço vigente decide.
    def cheapest_allowed
      allowed_models.min_by { |model| model.current_price&.input_cents_per_million || Float::INFINITY }
    end

    def plan
      return @plan if defined?(@plan)

      @plan = subscription_plan(account) || subscription_plan(account.agency)
    end

    def subscription_plan(owner)
      subscription = owner&.subscription
      subscription&.grants_plan? ? subscription.plan : nil
    end
  end
end
```

- [ ] **Step 4: Commit**

```bash
git add hdevCRM/app/services/ai/model_not_allowed_error.rb hdevCRM/app/services/ai/model_resolver.rb hdevCRM/spec/services/ai/model_resolver_spec.rb
git commit -m "F8: ModelResolver com gate estrito, fallback com warn e cadeia de plano"
```

---

### Task 6: `AnthropicService` — client injetado e gate na execução

**Files:**
- Modify: `hdevCRM/app/services/ai/anthropic_service.rb:29-39` (`raw_chat`), `:85-91` (`client`), `:93-103` (`record_usage`)
- Create: `hdevCRM/spec/services/ai/anthropic_service_spec.rb`

**Interfaces:**
- Consumes: `Ai::ModelResolver#resolve!` (Task 5).
- Produces: `raw_chat` resolve o modelo a cada chamada, manda `resolution.provider_model_id` no wire e grava `resolution.model.canonical_id` no `AiUsageEvent`. `DEFAULT_MODEL` continua `'claude-haiku-4-5'`.

- [ ] **Step 1: Conferir a doc do gem antes de codar o client Bedrock**

WebFetch em `https://github.com/anthropics/anthropic-sdk-ruby` com prompt "Extract the constructor signatures of Anthropic::Client and Anthropic::BedrockMantleClient (aws region / credentials params)". Se `BedrockMantleClient` aceitar credenciais explícitas, usar os campos da conexão; senão, construir com `aws_region:` e deixar comentário de que as credenciais AWS vêm da cadeia padrão do SDK da AWS (env/instance profile) — os campos `aws_*` da conexão ficam guardados pra quando o client suportar.

- [ ] **Step 2: Spec (primeiro spec direto do service)**

```ruby
require 'rails_helper'

RSpec.describe Ai::AnthropicService do
  let(:account) { create(:account) }
  let(:service) { described_class.new(account: account, feature: 'chatbot') }
  let(:api_response) do
    instance_double(Anthropic::Message, usage: instance_double(Anthropic::Usage, input_tokens: 10, output_tokens: 5))
  end

  def stub_client
    messages = double('messages')
    client = double('anthropic client', messages: messages)
    allow(service).to receive(:build_client).and_return(client)
    messages
  end

  describe '#raw_chat' do
    it 'sends the provider_model_id on the wire and records the canonical_id' do
      model = create(:ai_model, canonical_id: 'canonico-1', provider_model_id: 'wire-1')
      messages = stub_client
      expect(messages).to receive(:create).with(hash_including(model: 'wire-1')).and_return(api_response)

      service.raw_chat(messages: [{ role: 'user', content: 'oi' }], model: 'canonico-1')

      expect(AiUsageEvent.last.model).to eq('canonico-1')
    end

    it 'degrades to the plan default when the saved model is out of the plan' do
      allowed = create(:ai_model, canonical_id: 'liberado', provider_model_id: 'wire-liberado')
      blocked = create(:ai_model, canonical_id: 'barrado')
      plan = create(:plan)
      plan.update!(ai_model_ids: [allowed.id])
      create(:subscription, :active, owner: account, plan: plan)

      messages = stub_client
      expect(messages).to receive(:create).with(hash_including(model: 'wire-liberado')).and_return(api_response)

      service.raw_chat(messages: [{ role: 'user', content: 'oi' }], model: blocked.canonical_id)
    end

    it 'raises the rescuable error when the plan releases nothing' do
      plan = create(:plan)
      create(:subscription, :active, owner: account, plan: plan)

      expect do
        service.raw_chat(messages: [{ role: 'user', content: 'oi' }])
      end.to raise_error(Ai::ModelNotAllowedError)
    end
  end
end
```

(Se `Anthropic::Message`/`Anthropic::Usage` não existirem com esses nomes no gem, usar `double` simples com `usage.input_tokens`/`output_tokens` — o contrato do spec é o mesmo.)

- [ ] **Step 3: Implementação**

Em `raw_chat`, depois do check de quota:

```ruby
      resolution = Ai::ModelResolver.new(account: account).resolve!(model)

      params = { model: resolution.provider_model_id, max_tokens: max_tokens, messages: messages }
      params[:system] = system if system.present?
      params[:tools] = tools.map { |tool_class| tool_definition(tool_class) } if tools.present?

      response = client_for(resolution).messages.create(**params)
      record_usage(resolution.model.canonical_id, response)
      response
```

No `private`, substituindo `client`/`api_key`:

```ruby
    # F8: o client nasce da conexão do catálogo — direta e Bedrock viram a
    # mesma classe. Memoizado por conexão (uma instância de service pode
    # tocar mais de uma conexão num tool loop com modelos distintos).
    def client_for(resolution)
      @clients ||= {}
      @clients[resolution.connection.id] ||= build_client(resolution.connection)
    end

    def build_client(connection)
      case connection.modality
      when 'bedrock'
        Anthropic::BedrockMantleClient.new(aws_region: connection.region)
      else
        Anthropic::Client.new(api_key: connection.resolved_api_key)
      end
    end
```

`record_usage(model, response)` não muda de corpo — só passa a receber o canonical.

- [ ] **Step 4: Varredura de colaterais** — `grep -rn "AnthropicService" spec/` e revisar cada spec que instancia o service de verdade (hoje: `agent_reply_service_spec`, `copilot_service_spec`, `tool_loop_spec` usa service fake). Onde o spec stubava `client`, trocar pelo stub de `build_client`. Onde usa modelo string solta (ex: `'claude-opus-4-8'`), o catálogo seedado do banco de teste já resolve.

- [ ] **Step 5: Commit**

```bash
git add hdevCRM/app/services/ai/anthropic_service.rb hdevCRM/spec/services/ai/anthropic_service_spec.rb
git commit -m "F8: client injetado pela conexao; raw_chat resolve e gateia a cada chamada"
```

---

### Task 7: Gate no controller + endpoint de modelos + I18n

**Files:**
- Modify: `hdevCRM/app/controllers/api/v1/accounts/ai_agents_controller.rb`
- Modify: `hdevCRM/config/routes.rb:70` (`resource :ai_agent`)
- Modify: `hdevCRM/config/locales/api_errors.en.yml` e `api_errors.pt_BR.yml`
- Modify: `hdevCRM/spec/controllers/api/v1/accounts/ai_agent_controller_spec.rb`

**Interfaces:**
- Consumes: `Ai::ModelResolver#allowed?` / `#allowed_models`.
- Produces: `PUT /api/v1/accounts/:id/ai_agent` devolve 422 + `{ error: }` pra modelo fora do plano; `GET /api/v1/accounts/:id/ai_agent/models` devolve `[{canonical_id, display_name, default}]`.

- [ ] **Step 1: Rota**

```ruby
          resource :ai_agent, only: [:show, :update] do
            get :models
          end
```

- [ ] **Step 2: I18n** — em `api_errors.en.yml`, dentro de `errors:` (irmão de `subscriptions:`):

```yaml
    ai_agents:
      model_not_in_plan: 'This AI model is not included in your plan'
```

Em `api_errors.pt_BR.yml`:

```yaml
    ai_agents:
      model_not_in_plan: 'Este modelo de IA não está incluído no seu plano'
```

- [ ] **Step 3: Specs (adicionar ao spec existente do controller)**

```ruby
  describe 'GET /api/v1/accounts/:id/ai_agent/models' do
    it 'lists only the models the plan releases' do
      allowed = create(:ai_model, display_name: 'Liberado')
      create(:ai_model, display_name: 'Barrado')
      plan = create(:plan)
      plan.update!(ai_model_ids: [allowed.id])
      create(:subscription, :active, owner: account, plan: plan)

      get "/api/v1/accounts/#{account.id}/ai_agent/models",
          headers: admin.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body.pluck('canonical_id')).to contain_exactly(allowed.canonical_id)
    end
  end

  describe 'PUT com modelo fora do plano' do
    it 'rejects with 422 and the I18n message' do
      allowed = create(:ai_model)
      blocked = create(:ai_model)
      plan = create(:plan)
      plan.update!(ai_model_ids: [allowed.id])
      create(:subscription, :active, owner: account, plan: plan)

      put "/api/v1/accounts/#{account.id}/ai_agent",
          params: { ai_agent_model: blocked.canonical_id },
          headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('This AI model is not included in your plan')
      expect(account.reload.custom_attributes['ai_agent_model']).not_to eq(blocked.canonical_id)
    end
  end
```

(Adaptar `account`/`admin` aos `let` que o spec existente já define — ler o arquivo antes.)

- [ ] **Step 4: Controller**

```ruby
  def update
    if params[:ai_agent_model].present? && !resolver.allowed?(params[:ai_agent_model])
      return render json: { error: I18n.t('errors.ai_agents.model_not_in_plan') }, status: :unprocessable_entity
    end

    attrs = Current.account.custom_attributes
    permitted_params.each { |key, value| attrs[key] = value }
    Current.account.save!
    render json: config_json
  end

  def models
    render json: resolver.allowed_models.order(:display_name).map { |model|
      { canonical_id: model.canonical_id, display_name: model.display_name, default: model.default_for_provider }
    }
  end

  private

  def resolver
    @resolver ||= Ai::ModelResolver.new(account: Current.account)
  end
```

- [ ] **Step 5: Commit**

```bash
git add hdevCRM/app/controllers/api/v1/accounts/ai_agents_controller.rb hdevCRM/config/routes.rb hdevCRM/config/locales/api_errors.en.yml hdevCRM/config/locales/api_errors.pt_BR.yml hdevCRM/spec/controllers/api/v1/accounts/ai_agent_controller_spec.rb
git commit -m "F8: 422 pra modelo fora do plano e endpoint de modelos liberados"
```

---

### Task 8: UI — `MODEL_OPTIONS` hardcoded morre (verificação LOCAL)

**Files:**
- Modify: `hdevCRM/app/javascript/dashboard/api/aiAgent.js`
- Modify: `hdevCRM/app/javascript/dashboard/routes/dashboard/settings/aiAgent/Index.vue:11-16`
- Test: spec vitest vizinho do módulo de API (seguir o padrão de `app/javascript/dashboard/api/specs/`)

**Interfaces:**
- Consumes: `GET .../ai_agent/models` (Task 7).
- Produces: `AiAgentAPI.getModels()`; o select do Index.vue alimentado pelo servidor.

- [ ] **Step 1:** Ler `aiAgent.js` e um spec vizinho em `dashboard/api/specs/` pra copiar o molde. Adicionar:

```js
  getModels() {
    return axios.get(`${this.url}/models`);
  }
```

- [ ] **Step 2:** No `Index.vue`: apagar `MODEL_OPTIONS` e `DEFAULT_MODEL` fixos; `const modelOptions = ref([]);` carregado no `fetchAll` via `AiAgentAPI.getModels()`; o default do select vem do item com `default: true` (fallback: primeiro da lista). O `config.ai_agent_model` salvo continua vindo do `show` como hoje.

- [ ] **Step 3: Verificação local (roda AQUI, antes de empurrar)**

```bash
cd hdevCRM
corepack pnpm exec vitest run app/javascript/dashboard/api/specs/aiAgent.spec.js
corepack pnpm exec eslint --fix app/javascript/dashboard/api/aiAgent.js app/javascript/dashboard/routes/dashboard/settings/aiAgent/Index.vue
```

Esperado: vitest PASS; eslint sem erro.

- [ ] **Step 4: Commit**

```bash
git add hdevCRM/app/javascript/dashboard/api/aiAgent.js hdevCRM/app/javascript/dashboard/routes/dashboard/settings/aiAgent/Index.vue hdevCRM/app/javascript/dashboard/api/specs/
git commit -m "F8: select de modelos busca do servidor ja filtrado pelo plano"
```

---

### Task 9: Dashboards do super admin

**Files:**
- Create: `hdevCRM/app/dashboards/ai_connection_dashboard.rb`, `ai_model_dashboard.rb`, `ai_model_price_dashboard.rb`
- Create: `hdevCRM/app/controllers/super_admin/ai_connections_controller.rb`, `ai_models_controller.rb`, `ai_model_prices_controller.rb`
- Modify: `hdevCRM/config/routes.rb:667` (depois de `resources :subscriptions`)
- Modify: `hdevCRM/app/dashboards/plan_dashboard.rb` (has_many de modelos)
- Create: `hdevCRM/spec/controllers/super_admin/ai_connections_controller_spec.rb`

**Interfaces:**
- Consumes: models das Tasks 1–4; molde de `PlanDashboard`/`SuperAdmin::PlansController`; spec no molde de `spec/controllers/super_admin/plans_controller_spec.rb` (`sign_in(super_admin, scope: :super_admin)`).

- [ ] **Step 1: Rotas** (ordem = ordem da sidebar):

```ruby
      resources :ai_connections, only: [:index, :new, :create, :show, :edit, :update]
      resources :ai_models, only: [:index, :new, :create, :show, :edit, :update]
      resources :ai_model_prices, only: [:index, :new, :create, :show]
```

(`ai_model_prices` sem edit/update/destroy DE PROPÓSITO: preço se troca supersedendo + criando, nunca editando — o controller de create marca o vigente anterior.)

- [ ] **Step 2: Spec da chave nunca exposta**

```ruby
require 'rails_helper'

RSpec.describe 'Super Admin AI connections API', type: :request do
  let!(:super_admin) { create(:super_admin) }

  it 'never renders the api_key value, only the mask' do
    create(:ai_connection, label: 'Principal', api_key: 'sk-super-secreto-9876')
    sign_in(super_admin, scope: :super_admin)

    get '/super_admin/ai_connections'
    expect(response.body).not_to include('sk-super-secreto')

    get "/super_admin/ai_connections/#{AiConnection.last.id}"
    expect(response.body).not_to include('sk-super-secreto')
    expect(response.body).to include('••••9876')
  end

  it 'creates a connection with an encrypted key from the form' do
    sign_in(super_admin, scope: :super_admin)

    post '/super_admin/ai_connections',
         params: { ai_connection: { provider: 'anthropic', modality: 'direct', label: 'Nova', api_key: 'sk-nova' } }

    expect(AiConnection.find_by(label: 'Nova').api_key).to eq('sk-nova')
  end
end
```

- [ ] **Step 3: Dashboards** — `AiConnectionDashboard`: `api_key: Field::Password` e `aws_secret_access_key: Field::Password` (só em FORM_ATTRIBUTES); `masked_api_key: Field::String` (só em SHOW/COLLECTION). Demais campos `Field::String`/`Select`/`Boolean` no molde do `PlanDashboard` (os `Select` de enum com lambda de I18n `administrate.values.*` como o `plan_type` faz). `AiModelDashboard`: todos os campos + `ai_connection: Field::BelongsTo`. `AiModelPriceDashboard`: `ai_model: Field::BelongsTo` + cents + `effective_from`/`superseded_at` (`superseded_at` fora do form). Controllers vazios herdando de `SuperAdmin::ApplicationController` (molde do `PlansController`).

- [ ] **Step 4: `PlanDashboard`** — adicionar `ai_models: Field::HasMany` em `ATTRIBUTE_TYPES`, em `SHOW_PAGE_ATTRIBUTES` e em `FORM_ATTRIBUTES` (o Administrate permite `ai_model_ids` sozinho a partir do Field::HasMany no form).

- [ ] **Step 5: Chaves I18n do Administrate** — conferir onde `administrate.values.plan_type.*` vive (`config/locales/administrate.*.yml` ou similar — grep) e adicionar `provider`/`modality` nos dois idiomas.

- [ ] **Step 6: Commit**

```bash
git add hdevCRM/app/dashboards hdevCRM/app/controllers/super_admin hdevCRM/config/routes.rb hdevCRM/config/locales hdevCRM/spec/controllers/super_admin/ai_connections_controller_spec.rb
git commit -m "F8: dashboards de conexao/catalogo/preco; chave so mascarada; plano escolhe modelos"
```

---

### Task 10: CI no espelho, schema, PR

- [ ] **Step 1:** Push + PR:

```bash
git push -u origin feat/f8-conexoes-ia
gh pr create --title "F8: conexoes de IA, catalogo e gate por plano" --body-file <arquivo-tmp>
```

(Checks do PR privado = vermelhos por billing; ignorar.)

- [ ] **Step 2:** Staging curto `C:\Users\hdev\AppData\Local\Temp\hdev-ci-sync` via `git archive feat/f8-conexoes-ia hdevCRM baileys-service .github .gitignore VERSION | tar -x`, `git init -b main`, README de sync, restaurar bits 100755 (16 arquivos), commit `sync: feat/f8-conexoes-ia @ <sha>`, conferir `git log --oneline -1`.

- [ ] **Step 3:** **Harvey dá o push**: `git push --force https://github.com/solutionshdev-sudo/hdev-crm-ci.git HEAD:refs/heads/main`.

- [ ] **Step 4:** Acompanhar `gh run list --repo solutionshdev-sudo/hdev-crm-ci`; esperar 4 jobs verdes (rspec ~6470+ exemplos). Se vermelho: iterar com `workflow_dispatch` + `spec_path` num arquivo só antes de re-sync completo.

- [ ] **Step 5:** Baixar artifact `schema` do run verde, conferir diff (4 tabelas novas + versão `2026_08_06_000005`), commitar `db/schema.rb`, push da branch, re-sync, push do Harvey, verde final.

- [ ] **Step 6:** Merge (comando do Harvey):

```bash
gh pr merge <numero> --repo solutionshdev-sudo/hdev-crm --squash --delete-branch
```
