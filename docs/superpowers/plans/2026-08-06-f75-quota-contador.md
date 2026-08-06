# F7.5 — Quota por contador atômico — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar o `SUM(total_tokens)` do hot path da quota de IA por um contador atômico por dono/mês, e mover o alerta de limiar (mailer) da request para um job Sidekiq.

**Architecture:** Tabela `ai_usage_counters` (owner polimórfico Account|Agency, um registro por mês) incrementada por `after_create` de `AiUsageEvent` com `update_counters` (mesmo padrão de `AiCreditEvent.record!`). `Ai::QuotaService#account_usage`/`#agency_usage` viram lookup por índice único. `check_thresholds!` fica intacto no service, mas é chamado por `Ai::QuotaAlertJob`, enfileirado em `after_create_commit`. Spec: `docs/superpowers/specs/2026-08-06-f75-quota-contador-design.md`.

**Tech Stack:** Rails 7.1 (migration `[7.1]`), FactoryBot, RSpec, Sidekiq via ActiveJob.

## Global Constraints

- **Ruby NÃO roda nesta máquina.** Nenhum passo "rode o teste" local para Ruby: a verificação é o CI do espelho público `solutionshdev-sudo/hdev-crm-ci` (Task 6). Os passos de teste dos Tasks 1–5 são "escreva e siga" — a rodada vermelho→verde acontece de uma vez no CI.
- Custo acumulado é `decimal(14, 8)` (NUNCA cents/bigint) — decisão do design doc.
- `find_or_create_by!` + rescue `ActiveRecord::RecordNotUnique` + retry; **nunca** `create_or_find_by!`.
- Sem texto novo visível ao usuário → sem chave I18n nesta fase.
- Nunca tocar em `enterprise/` nem no `LICENSE`.
- Branch de trabalho: `feat/f75-quota-contador` a partir da `main`.
- Comentários de código em pt-BR, no estilo dos vizinhos (`ai_credit_event.rb`).
- `db/schema.rb` NÃO se edita à mão: vem do artifact `schema` do CI verde (Task 6).

---

### Task 0: Branch

**Files:** nenhum.

- [ ] **Step 1: Criar a branch**

```bash
cd "c:/Users/hdev/Downloads/backup-20260723T235954Z-1-001/backup/Hdev-CRM"
git checkout -b feat/f75-quota-contador main
```

---

### Task 1: Migration `create_ai_usage_counters` (com backfill)

**Files:**
- Create: `hdevCRM/db/migrate/20260806000001_create_ai_usage_counters.rb`

**Interfaces:**
- Produces: tabela `ai_usage_counters` com colunas `owner_type string NOT NULL`, `owner_id bigint NOT NULL`, `period_start date NOT NULL`, `tokens bigint NOT NULL default 0`, `cost decimal(14,8) NOT NULL default 0`, `created_at/updated_at`; índice único `index_ai_usage_counters_on_owner_and_period` em `(owner_type, owner_id, period_start)`. Backfill dos eventos existentes agrupado por dono e mês (UTC — desvio de fuso na borda aceito pelo design doc).

- [ ] **Step 1: Escrever a migration**

```ruby
class CreateAiUsageCounters < ActiveRecord::Migration[7.1]
  # F7.5: tira o SUM(total_tokens) do hot path da quota. Um registro por
  # dono (Account|Agency) por mês; incrementado atomicamente pelo
  # after_create de AiUsageEvent. Custo em decimal(14,8) — mesma escala do
  # evento; centavo arredondado por evento zeraria conta pequena.
  def up
    create_table :ai_usage_counters do |t|
      t.string :owner_type, null: false
      t.bigint :owner_id, null: false
      t.date :period_start, null: false
      t.bigint :tokens, null: false, default: 0
      t.decimal :cost, precision: 14, scale: 8, null: false, default: 0
      t.timestamps
    end
    add_index :ai_usage_counters, [:owner_type, :owner_id, :period_start],
              unique: true, name: 'index_ai_usage_counters_on_owner_and_period'

    # Backfill: sem ele, deploy no meio do mês zera o consumo aparente e
    # conta que já estourou a quota volta a gastar. Agrupa por mês em UTC
    # (date_trunc); o runtime usa Time.zone — desvio de borda aceito para
    # dado histórico (design doc, seção 1).
    execute <<~SQL.squish
      INSERT INTO ai_usage_counters (owner_type, owner_id, period_start, tokens, cost, created_at, updated_at)
      SELECT 'Account', account_id, DATE_TRUNC('month', created_at)::date,
             SUM(total_tokens), SUM(cost), NOW(), NOW()
      FROM ai_usage_events
      GROUP BY account_id, DATE_TRUNC('month', created_at)::date
    SQL

    execute <<~SQL.squish
      INSERT INTO ai_usage_counters (owner_type, owner_id, period_start, tokens, cost, created_at, updated_at)
      SELECT 'Agency', agency_id, DATE_TRUNC('month', created_at)::date,
             SUM(total_tokens), SUM(cost), NOW(), NOW()
      FROM ai_usage_events
      WHERE agency_id IS NOT NULL
      GROUP BY agency_id, DATE_TRUNC('month', created_at)::date
    SQL
  end

  def down
    drop_table :ai_usage_counters
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add hdevCRM/db/migrate/20260806000001_create_ai_usage_counters.rb
git commit -m "F7.5: migration ai_usage_counters com backfill por dono/mes"
```

---

### Task 2: Model `AiUsageCounter` + factory + spec

**Files:**
- Create: `hdevCRM/app/models/ai_usage_counter.rb`
- Create: `hdevCRM/spec/factories/ai_usage_counters.rb`
- Create: `hdevCRM/spec/models/ai_usage_counter_spec.rb`

**Interfaces:**
- Consumes: tabela do Task 1.
- Produces: `AiUsageCounter.record!(owner:, period_start:, tokens:, cost:)` (incremento atômico, cria a linha se não existe, sobrevive à corrida) e `AiUsageCounter.current_for(owner)` → instância ou nil (mês corrente por `Time.zone`).

- [ ] **Step 1: Escrever o spec (comportamento antes da implementação)**

```ruby
require 'rails_helper'

RSpec.describe AiUsageCounter do
  let(:account) { create(:account) }
  let(:period) { Time.zone.today.beginning_of_month }

  describe '.record!' do
    it 'creates the counter row on first use' do
      described_class.record!(owner: account, period_start: period, tokens: 100, cost: 0.001)

      counter = described_class.find_by(owner: account, period_start: period)
      expect(counter.tokens).to eq(100)
      expect(counter.cost).to eq(0.001)
    end

    it 'accumulates instead of overwriting on subsequent events' do
      described_class.record!(owner: account, period_start: period, tokens: 100, cost: 0.001)
      described_class.record!(owner: account, period_start: period, tokens: 50, cost: 0.0005)

      counter = described_class.find_by(owner: account, period_start: period)
      expect(counter.tokens).to eq(150)
      expect(counter.cost).to eq(0.0015)
    end

    it 'keeps separate rows per owner and per month' do
      agency = create(:agency)
      described_class.record!(owner: account, period_start: period, tokens: 10, cost: 0.1)
      described_class.record!(owner: agency, period_start: period, tokens: 20, cost: 0.2)
      described_class.record!(owner: account, period_start: period - 1.month, tokens: 30, cost: 0.3)

      expect(described_class.count).to eq(3)
      expect(described_class.find_by(owner: account, period_start: period).tokens).to eq(10)
    end

    it 'survives the creation race by retrying after RecordNotUnique' do
      calls = 0
      allow(described_class).to receive(:find_or_create_by!).and_wrap_original do |original, *args, &block|
        calls += 1
        raise ActiveRecord::RecordNotUnique, 'duplicate key' if calls == 1

        original.call(*args, &block)
      end

      expect do
        described_class.record!(owner: account, period_start: period, tokens: 5, cost: 0.05)
      end.not_to raise_error

      expect(described_class.find_by(owner: account, period_start: period).tokens).to eq(5)
    end
  end

  describe '.current_for' do
    it 'returns the counter of the current month' do
      described_class.record!(owner: account, period_start: period, tokens: 42, cost: 0.42)
      described_class.record!(owner: account, period_start: period - 1.month, tokens: 999, cost: 9.99)

      expect(described_class.current_for(account).tokens).to eq(42)
    end

    it 'is nil when the owner has no usage this month' do
      expect(described_class.current_for(account)).to be_nil
    end
  end
end
```

- [ ] **Step 2: Escrever a factory**

```ruby
# frozen_string_literal: true

FactoryBot.define do
  factory :ai_usage_counter do
    association :owner, factory: :account
    period_start { Time.zone.today.beginning_of_month }
    tokens { 0 }
    cost { 0 }
  end
end
```

- [ ] **Step 3: Escrever o model**

```ruby
# == Schema Information
#
# Table name: ai_usage_counters
#
#  id           :bigint           not null, primary key
#  cost         :decimal(14, 8)   default(0.0), not null
#  owner_type   :string           not null
#  period_start :date             not null
#  tokens       :bigint           default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  owner_id     :bigint           not null
#
# Indexes
#
#  index_ai_usage_counters_on_owner_and_period  (owner_type,owner_id,period_start) UNIQUE
#
class AiUsageCounter < ApplicationRecord
  belongs_to :owner, polymorphic: true

  # Incremento atômico do consumo do mês — mesmo padrão de
  # AiCreditEvent.record!: update_counters vira "tokens = tokens + N" no
  # banco, então dois eventos simultâneos não sobrescrevem o acumulado.
  # A corrida na CRIAÇÃO da linha é decidida pelo índice único: o perdedor
  # pega RecordNotUnique e o retry acha a linha que o vencedor inseriu.
  # (find_or_create_by!, não create_or_find_by! — armadilha anotada da F7.)
  def self.record!(owner:, period_start:, tokens:, cost:)
    counter = find_or_create_by!(owner: owner, period_start: period_start)
    update_counters(counter.id, tokens: tokens, cost: cost) # rubocop:disable Rails/SkipsModelValidations
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def self.current_for(owner)
    find_by(owner: owner, period_start: Time.zone.today.beginning_of_month)
  end
end
```

- [ ] **Step 4: Commit**

```bash
git add hdevCRM/app/models/ai_usage_counter.rb hdevCRM/spec/factories/ai_usage_counters.rb hdevCRM/spec/models/ai_usage_counter_spec.rb
git commit -m "F7.5: AiUsageCounter com incremento atomico e lookup do mes"
```

---

### Task 3: Callbacks em `AiUsageEvent` + `Ai::QuotaAlertJob`

**Files:**
- Modify: `hdevCRM/app/models/ai_usage_event.rb` (callbacks novos; nada existente muda)
- Create: `hdevCRM/app/jobs/ai/quota_alert_job.rb`
- Create: `hdevCRM/spec/jobs/ai/quota_alert_job_spec.rb`
- Modify: `hdevCRM/spec/models/ai_usage_event_spec.rb` (describe novo no fim)

**Interfaces:**
- Consumes: `AiUsageCounter.record!` (Task 2).
- Produces: todo `AiUsageEvent` criado incrementa o contador da conta (e da agência quando houver) na mesma transação, e enfileira `Ai::QuotaAlertJob.perform_later(account_id)` pós-commit. `Ai::QuotaAlertJob#perform(account_id)` chama `Ai::QuotaService#check_thresholds!`.

- [ ] **Step 1: Adicionar specs no `ai_usage_event_spec.rb` (describe novo, após `.summary`)**

```ruby
  describe 'usage counters (F7.5)' do
    let(:agency) { create(:agency) }
    let(:account) { create(:account, agency: agency) }

    it 'increments the account and agency counters in the month of the event' do
      create(:ai_usage_event, account: account, input_tokens: 1000, output_tokens: 500)
      create(:ai_usage_event, account: account, input_tokens: 200, output_tokens: 100)

      period = Time.zone.today.beginning_of_month
      expect(AiUsageCounter.find_by(owner: account, period_start: period).tokens).to eq(1800)
      expect(AiUsageCounter.find_by(owner: agency, period_start: period).tokens).to eq(1800)
    end

    it 'matches the SUM over events, tokens and cost alike' do
      [[1000, 500], [123, 45], [10, 1]].each do |input, output|
        create(:ai_usage_event, account: account, input_tokens: input, output_tokens: output)
      end

      counter = AiUsageCounter.current_for(account)
      events = described_class.where(account_id: account.id)
      expect(counter.tokens).to eq(events.sum(:total_tokens))
      expect(counter.cost).to eq(events.sum(:cost))
    end

    it 'does not touch the agency counter for accounts without an agency' do
      create(:ai_usage_event, account: create(:account), input_tokens: 10, output_tokens: 10)

      expect(AiUsageCounter.where(owner_type: 'Agency')).to be_empty
    end

    it 'keys the counter to the month the event was created in' do
      travel_to(2.months.ago) do
        create(:ai_usage_event, account: account, input_tokens: 100, output_tokens: 0)
      end

      expect(AiUsageCounter.current_for(account)).to be_nil
      expect(AiUsageCounter.find_by(owner: account).tokens).to eq(100)
    end

    it 'enqueues the quota alert job instead of mailing synchronously' do
      expect do
        create(:ai_usage_event, account: account, input_tokens: 10, output_tokens: 10)
      end.to have_enqueued_job(Ai::QuotaAlertJob).with(account.id)
        .and(not_have_enqueued_mail(AdministratorNotifications::AccountNotificationMailer, :ai_quota_threshold))
    end
  end
```

- [ ] **Step 2: Adicionar os callbacks no `ai_usage_event.rb`**

Depois de `before_validation :compute_totals` (linha 34), inserir:

```ruby
  after_create :increment_usage_counters
  after_create_commit :enqueue_quota_alert
```

E no `private`, depois de `compute_totals`:

```ruby
  # F7.5: o contador é quem responde a quota no hot path — incrementa na
  # mesma transação do evento (consistência) e o alerta de limiar roda em
  # job pós-commit (o mailer saiu da request). O gatilho mora aqui, não no
  # AnthropicService: qualquer fonte futura de evento alerta também.
  def increment_usage_counters
    period = created_at.in_time_zone.to_date.beginning_of_month
    AiUsageCounter.record!(owner: account, period_start: period, tokens: total_tokens, cost: cost)
    AiUsageCounter.record!(owner: agency, period_start: period, tokens: total_tokens, cost: cost) if agency_id.present?
  end

  def enqueue_quota_alert
    Ai::QuotaAlertJob.perform_later(account_id)
  end
```

- [ ] **Step 3: Escrever o job spec**

```ruby
require 'rails_helper'

RSpec.describe Ai::QuotaAlertJob do
  it 'runs the threshold check for the account' do
    account = create(:account)
    service = instance_double(Ai::QuotaService, check_thresholds!: nil)
    allow(Ai::QuotaService).to receive(:new).with(account: account).and_return(service)

    described_class.perform_now(account.id)

    expect(service).to have_received(:check_thresholds!)
  end

  it 'does nothing when the account no longer exists' do
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end
```

- [ ] **Step 4: Escrever o job**

```ruby
module Ai
  # Disparado pelo after_create_commit de AiUsageEvent. Burro de propósito:
  # cooldown Redis, limiares e mailer continuam em
  # Ai::QuotaService#check_thresholds!, testável sem job no meio.
  class QuotaAlertJob < ApplicationJob
    queue_as :default

    def perform(account_id)
      account = Account.find_by(id: account_id)
      return if account.blank?

      Ai::QuotaService.new(account: account).check_thresholds!
    end
  end
end
```

- [ ] **Step 5: Commit**

```bash
git add hdevCRM/app/models/ai_usage_event.rb hdevCRM/app/jobs/ai/quota_alert_job.rb hdevCRM/spec/jobs/ai/quota_alert_job_spec.rb hdevCRM/spec/models/ai_usage_event_spec.rb
git commit -m "F7.5: AiUsageEvent incrementa contadores e enfileira QuotaAlertJob"
```

---

### Task 4: `Ai::QuotaService` lê o contador

**Files:**
- Modify: `hdevCRM/app/services/ai/quota_service.rb:43-69`
- Modify: `hdevCRM/spec/services/ai/quota_service_spec.rb:31-39`

**Interfaces:**
- Consumes: `AiUsageCounter.current_for(owner)` (Task 2); callbacks do Task 3 (os specs criam eventos e leem via contador).
- Produces: `#account_usage` e `#agency_usage` com o mesmo contrato de hoje (Integer, 0 quando sem uso), agora O(1).

- [ ] **Step 1: Ajustar o spec "ignores usage from previous months" (linhas 35-39)**

`update_columns` depois do create burla o callback — o contador já recebeu o incremento no mês corrente. Criar o evento JÁ no passado:

```ruby
    it 'ignores usage from previous months' do
      account.update!(custom_attributes: { 'ai_monthly_tokens' => 1000 })
      travel_to(2.months.ago) do
        create(:ai_usage_event, account: account, input_tokens: 2000, output_tokens: 0)
      end
      expect(service.exceeded?).to be(false)
    end
```

- [ ] **Step 2: Trocar as leituras no service (linhas 61-69)**

```ruby
    # F7.5: leitura O(1) no contador (ai_usage_counters) em vez de
    # SUM(total_tokens) — o ToolLoop consulta exceeded? a cada iteração.
    def account_usage
      AiUsageCounter.current_for(account)&.tokens || 0
    end

    def agency_usage
      return 0 if agency.blank?

      AiUsageCounter.current_for(agency)&.tokens || 0
    end
```

- [ ] **Step 3: Atualizar o comentário de `check_thresholds!` (linhas 43-46)**

De "Chamado pelo Ai::AnthropicService#record_usage logo após gravar o AiUsageEvent." para:

```ruby
    # Chamado pelo Ai::QuotaAlertJob (enfileirado no after_create_commit de
    # AiUsageEvent — F7.5 tirou o mailer da request). Nunca pode derrubar o
    # fluxo de IA: erro de Redis/mailer vira só log. Cooldown de 24h por
    # limiar (80/100) em Redis evita floodar o admin a cada iteração do
    # tool loop.
```

- [ ] **Step 4: Commit**

```bash
git add hdevCRM/app/services/ai/quota_service.rb hdevCRM/spec/services/ai/quota_service_spec.rb
git commit -m "F7.5: QuotaService le o contador; spec de mes anterior via travel_to"
```

---

### Task 5: `Ai::AnthropicService` perde o check síncrono

**Files:**
- Modify: `hdevCRM/app/services/ai/anthropic_service.rb:93-103`

**Interfaces:**
- Consumes: nada novo. O enfileiramento agora é responsabilidade do model (Task 3) — aqui só se REMOVE.

- [ ] **Step 1: Remover a linha síncrona**

Em `#record_usage`, apagar a linha `QuotaService.new(account: account).check_thresholds!` (linha 102). O método fica:

```ruby
    def record_usage(model, response)
      AiUsageEvent.record!(
        account: account,
        model: model,
        input_tokens: response.usage.input_tokens,
        output_tokens: response.usage.output_tokens,
        feature: feature,
        conversation: conversation
      )
    end
```

- [ ] **Step 2: Commit**

```bash
git add hdevCRM/app/services/ai/anthropic_service.rb
git commit -m "F7.5: alerta de quota sai da request (job assumiu no after_commit)"
```

---

### Task 6: CI no espelho, schema, PR

**Files:**
- Modify (após CI verde): `hdevCRM/db/schema.rb` (artifact `schema` do CI)

- [ ] **Step 1: Push da branch e PR no repo privado**

```bash
git push -u origin feat/f75-quota-contador
gh pr create --title "F7.5: quota por contador atomico" --body-file <arquivo-tmp-com-o-corpo>
```

(Corpo do PR via arquivo — PowerShell 5.1 mutila `-m`/`--body` longos. Checks do PR privado ficam vermelhos por billing: ignorar, quem valida é o espelho.)

- [ ] **Step 2: Montar o commit de sync do espelho**

Staging curto (MAX_PATH): `C:\Users\hdev\AppData\Local\Temp\hdev-ci-sync`, populado com `git archive | tar` a partir da branch, allowlist do `scripts/sync-ci-mirror.sh` (hdevCRM/, baileys-service/, .github/ — nunca _memoria/), bits 100755 restaurados. Conferir `git log --oneline -1` mostrando o commit `sync:`.

- [ ] **Step 3: Harvey dá o push** (bloqueado para o agente)

```bash
git push --force <url-do-espelho> HEAD:refs/heads/main
```

- [ ] **Step 4: Acompanhar o run**

```bash
gh run list --repo solutionshdev-sudo/hdev-crm-ci --limit 3
gh run view <id> --repo solutionshdev-sudo/hdev-crm-ci
```

Esperado: 4 jobs verdes (rspec ~15-18 min, agora ~6470 exemplos). `cancelled` = olhar duração antes de concluir (concurrency).

- [ ] **Step 5: Baixar o artifact `schema` e commitar o `db/schema.rb`**

```bash
gh run download <id> --repo solutionshdev-sudo/hdev-crm-ci -n schema -D <staging-tmp>
# copiar sobre hdevCRM/db/schema.rb na branch, conferir o diff (só a tabela nova + versão), commitar:
git commit -m "F7.5: schema.rb regenerado pelo CI (ai_usage_counters)"
```

(Schema tem CRLF history — conferir que o diff é só o conteúdo esperado, armadilha anotada da F4.)

- [ ] **Step 6: Re-sync do espelho com o schema commitado + push do Harvey + CI verde final**

- [ ] **Step 7: Merge — comando para o Harvey rodar**

```bash
gh pr merge <numero> --squash --delete-branch
```
