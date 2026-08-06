# F7.5 — Quota por contador atômico (design)

Data: 2026-08-06. Aprovado em conversa com o Harvey.
Referência: `plano-fases-6-11.md` §F7.5. Tem migration — baixar o artifact
`schema` do CI verde e commitar o `db/schema.rb`.

## Objetivo

Tirar o `SUM(total_tokens)` do hot path da IA. Hoje
`Ai::QuotaService#account_usage` (`hdevCRM/app/services/ai/quota_service.rb:61`)
e `#agency_usage` (`:65`) agregam `ai_usage_events` a cada chamada, e o
`Ai::ToolLoop` consulta `exceeded?` a cada iteração — até 8 por resposta.
Pior: `check_thresholds!` roda mailer + Redis **dentro da request**
(`anthropic_service.rb:102`). Depois desta fase: leitura de quota é um lookup
por índice único, e o alerta roda em Sidekiq.

## Desvios do plano (ambos aprovados pelo Harvey)

1. **`cost decimal(14, 8)`** em vez de `cost_cents bigint`. Um evento de
   Haiku custa ~$0.00045 (0.045 centavo); arredondar pra centavo a cada
   evento zera o acumulado em conta pequena — e custo por conta é o número
   de margem da F11. Decimal soma exato no Postgres, sem conversão em
   nenhuma ponta, e sobrevive à F8 (preço vira tabela editável).
2. **Backfill na própria migration.** Sem ele, no deploy no meio do mês todo
   contador nasce 0 e conta que já estourou a quota volta a gastar de graça
   até o mês virar.

## 1. Migration `create_ai_usage_counters`

```ruby
create_table :ai_usage_counters do |t|
  t.string  :owner_type, null: false
  t.bigint  :owner_id,   null: false
  t.date    :period_start, null: false
  t.bigint  :tokens, null: false, default: 0
  t.decimal :cost, precision: 14, scale: 8, null: false, default: 0
  t.timestamps
end
add_index :ai_usage_counters, [:owner_type, :owner_id, :period_start],
          unique: true, name: 'index_ai_usage_counters_on_owner_and_period'
```

Backfill (mesma migration, SQL puro — sem passar por model):

```sql
INSERT INTO ai_usage_counters (owner_type, owner_id, period_start, tokens, cost, created_at, updated_at)
SELECT 'Account', account_id, date_trunc('month', created_at)::date,
       SUM(total_tokens), SUM(cost), NOW(), NOW()
FROM ai_usage_events GROUP BY account_id, 2;
-- idem com 'Agency', agency_id, WHERE agency_id IS NOT NULL
```

Nota de fuso: o backfill agrupa por `date_trunc` em UTC e o runtime usa
`Time.zone` (America/Sao_Paulo). Eventos das ~3h de borda de mês podem cair
no balde vizinho — aceito: é migração one-shot de dado histórico, e o
contador do mês corrente converge com os incrementos novos.

## 2. Model `AiUsageCounter`

```ruby
class AiUsageCounter < ApplicationRecord
  belongs_to :owner, polymorphic: true

  def self.record!(owner:, period_start:, tokens:, cost:)
    counter = find_or_create_by!(owner: owner, period_start: period_start)
    update_counters(counter.id, tokens: tokens, cost: cost)
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def self.current_for(owner)
    find_by(owner: owner, period_start: Time.zone.today.beginning_of_month)
  end
end
```

- `find_or_create_by!` + rescue `RecordNotUnique` + retry — **não**
  `create_or_find_by!` (armadilha anotada da F7: cria primeiro e estoura
  `RecordInvalid` quando há validação; aqui a corrida é decidida pelo índice
  único, sem validação de uniqueness no model).
- `update_counters` é o mesmo incremento atômico de
  `AiCreditEvent.record!` (`ai_credit_event.rb:38`) — dois eventos
  simultâneos não sobrescrevem o acumulado um do outro. Leva o
  `# rubocop:disable Rails/SkipsModelValidations` igual lá.

## 3. `AiUsageEvent` — dois callbacks

```ruby
after_create :increment_usage_counters
after_create_commit :enqueue_quota_alert
```

- `increment_usage_counters` (dentro da transação do evento): incrementa o
  contador do `account` e, quando `agency_id` presente, o da `agency`.
  Chave do período: `created_at.in_time_zone.to_date.beginning_of_month` —
  casa com o `current_period` do QuotaService, que usa `Time.zone`.
- `enqueue_quota_alert` (**pós-commit**, pra o job não rodar antes do
  contador existir): `Ai::QuotaAlertJob.perform_later(account_id)`. O
  gatilho mora no model — qualquer fonte futura de evento dispara alerta,
  não só o AnthropicService.

## 4. `Ai::QuotaAlertJob`

```ruby
module Ai
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

Job burro de propósito (molde do `Ai::ReplyJob`); a inteligência continua
testável no service. Até 8 jobs por resposta de IA é ok: cada um é um
lookup de contador + Redis `SET NX`, e o cooldown de 24h já deduplica o
e-mail.

## 5. `Ai::QuotaService`

- `account_usage` → `AiUsageCounter.current_for(account)&.tokens || 0`
- `agency_usage` → idem com `agency`
- `check_thresholds!` — **assinatura e corpo intactos** (cooldown Redis 24h,
  `deliver_later`, rescue de tudo). Só o chamador muda: era
  `AnthropicService#record_usage` síncrono, vira o job. Os 8 specs
  existentes de `#check_thresholds!` continuam válidos sem editar.
- `account_summary` mantém o breakdown `usage` vindo dos eventos — é
  endpoint de dashboard, uma chamada por page-load, não hot path.

## 6. `Ai::AnthropicService#record_usage`

Perde a linha `QuotaService.new(account: account).check_thresholds!`
(`anthropic_service.rb:102`). Nada entra no lugar — o enfileiramento é do
model.

## Fora de escopo

- `api/v1/agencies/ai_usages_controller.rb` (agrega eventos por conta) —
  dashboard, não hot path.
- Limpeza/retenção de `ai_usage_events` — o ledger continua sendo a fonte
  de auditoria, igual ao par `AiCreditEvent`/`ai_extra_tokens`.
- I18n — nenhum texto novo visível ao usuário nesta fase.

## Verificação (CI do espelho)

1. **Contador vs. SUM** — N eventos variados (conta com e sem agência,
   meses diferentes) → contador de cada dono/mês == `SUM` dos eventos.
2. **Atomicidade** — dois `record!` no mesmo dono/período somam (não
   sobrescrevem); `RecordNotUnique` na corrida de criação é reabsorvido.
3. **Mailer nunca síncrono** — `raw_chat` com quota a 80%+ **não** enfileira
   mail direto e **enfileira** `Ai::QuotaAlertJob`; o job, executado,
   enfileira o mail (`have_enqueued_mail` via `check_thresholds!`).
4. **Backfill** — spec de migration não; conferência manual em produção
   (terminal EasyPanel): `SELECT` comparando contador vs. SUM por dono.
5. Suíte inteira verde (~6452 exemplos) + artifact `schema` commitado.
