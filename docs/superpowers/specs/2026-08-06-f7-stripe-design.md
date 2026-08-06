# F7 — Stripe e assinatura (design)

Data: 2026-08-06. Aprovado em conversa com o Harvey.
Referência: `plano-fases-6-11.md` §F7. Sem migration nesta fase.

## Objetivo

Fechar o ciclo do dinheiro: dar chamador a `Subscription#activate!`,
`#mark_past_due!` e `#cancel!` (`hdevCRM/app/models/subscription.rb:38-60`),
que hoje não têm nenhum. O webhook só muda **status** da Subscription — os
limites continuam sendo respondidos por `Plan::LimitEnforcer` via
`grants_plan?` (active || past_due), que já funciona.

## Quem vê Stripe (regra de negócio, decidida pelo Harvey)

| Quem | Superfície Stripe | Observação |
|---|---|---|
| Dono de agência | checkout + portal | Contrata plano `agency` conosco |
| Conta-filha de agência | **NENHUMA** | Paga a agência por fora; limites via `plan_allocations` |
| Conta direta (sem agência) | checkout + portal | Plano `direct` |

Regra dura no backend: `#checkout` e `#portal` do escopo de conta respondem
**403** (chave I18n `errors.subscriptions.agency_managed`) quando
`account.agency_id` presente. Não é só esconder botão no front.

## 1. Rotas

- **Sai o bloco `if HdevApp.enterprise?` inteiro** (`config/routes.rb:509-530`):
  aponta pra controllers deletados na Fase 3 (`enterprise/api/v1/accounts`,
  `webhooks/firecrawl`). Zero retrocompat.
- Entra, junto dos outros webhooks (~linha 617):
  `post 'webhooks/stripe', to: 'webhooks/stripe#process_payload'`
- Checkout/portal nos dois escopos:
  - `api/v1/accounts/:account_id` → `resource :subscription, only: [] do post :checkout; post :portal end`
    (módulo `api/v1/accounts/subscriptions_controller.rb`)
  - `api/v1/agencies/:agency_id` → idem (módulo `api/v1/agencies/subscriptions_controller.rb`)

## 2. `Webhooks::StripeController`

`ActionController::API`, molde do `Webhooks::BaileysController`.

- Segredo: `ENV.fetch('STRIPE_WEBHOOK_SECRET', nil)` (já no `.env.example`).
  Em branco → **401** + log — endpoint fechado enquanto não configurado.
- `Stripe::Webhook.construct_event(request.raw_post, request.headers['Stripe-Signature'], secret)`
  — faz HMAC e tolerância de timestamp (anti-replay).
  `SignatureVerificationError` → 401; `JSON::ParserError` → 400.
- Tipo fora dos 5 tratados → **200 sem gravar linha** (a tabela não vira
  firehose dos ~50 tipos do Stripe).

### Idempotência (aprovada: with_lock)

```ruby
event = StripeWebhookEvent.find_or_create_by!(stripe_event_id: ev.id) do |e|
  e.event_type = ev.type
  e.payload    = ev.to_hash
end                              # corrida no INSERT: índice único decide;
                                 # perdedor pega RecordNotUnique → refaz find
event.with_lock do               # SELECT ... FOR UPDATE
  return head :ok if event.processed?   # re-checagem DENTRO do lock
  dispatch!(event)               # mutação da Subscription
  event.mark_processed!          # mesma transação → tudo ou nada
end
```

- **Entrega concorrente** do mesmo `event_id`: um processa, o outro entra no
  lock depois, lê `processed?` e sai. Uma mutação.
- **Crash no meio**: rollback deixa a linha `pending`; o retry do Stripe
  reprocessa limpo. (O padrão "rescue duplicado → 200" engoliria o retry e a
  Subscription nunca ativaria — por isso o lock.)
- **Ordem de entrega não é garantida e não tentamos ordenar**: um
  `payment_failed` atrasado marca `past_due` de assinatura já paga — dano
  contido (`grants_plan?` aceita `past_due`), o próximo `invoice.paid`
  conserta. `deleted` é terminal no Stripe.

### Evento órfão / price desconhecido

Novo valor de enum `ignored: 3` em `StripeWebhookEvent.status` (coluna já é
integer — **sem migration**; valor vai no fim). Novo método `mark_ignored!(reason)`.
Nunca cria Subscription a partir de webhook, nunca casa por e-mail. Responde
**200** (4xx faria o Stripe retentar 3 dias um evento que nunca casa). A linha
fica de auditoria, visível no dashboard (item 5).

### Despacho (field paths conferidos na doc oficial, gem `stripe ~> 18.0`)

| evento | localiza Subscription por | ação |
|---|---|---|
| `checkout.session.completed` | `client_reference_id` (id da nossa Subscription, carimbado no checkout) | `activate!(stripe_subscription_id: session.subscription)` + gravar `stripe_customer_id: session.customer` (o portal precisa) |
| `invoice.paid` | `parent.subscription_details.subscription`; fallback `customer` → `stripe_customer_id` | `activate!(current_period_end: max(lines.data[].period.end))` |
| `invoice.payment_failed` | idem | `mark_past_due!` |
| `customer.subscription.updated` | `object.id` → `stripe_subscription_id` | sincroniza (abaixo) |
| `customer.subscription.deleted` | `object.id` | `cancel!` (suspende o dono) |

**Armadilhas de API já confirmadas na doc** (payloads de blog antigo estão
errados): `invoice.subscription` **não existe mais** no topo — é
`parent.subscription_details.subscription`; `current_period_end` saiu do topo
do Subscription — é `items.data[].current_period_end` (por item);
`invoice.period_end` NÃO é o período de serviço — o certo é
`lines.data[].period.end`.

`checkout.session.completed` não carrega período e **não** fazemos
`Stripe::Subscription.retrieve` no webhook (rede + stub em spec): o
`invoice.paid` chega na sequência com o período, e o `.compact` do `activate!`
já tolera a ausência.

### Handler de `customer.subscription.updated` (troca de plano no portal)

1. **Plano:** `items.data[0].price.id` → `Plan.find_by(stripe_price_id:)`.
   Diferente do atual → `update!(plan:)`. Price sem plano local →
   `mark_ignored!` com motivo (nunca chuta).
2. **Status** (8 do Stripe → nossos 4): `active`/`trialing` → `activate!`;
   `past_due`/`unpaid` → `mark_past_due!`; `canceled`/`incomplete_expired` →
   nada (o `deleted` chega e cuida); `incomplete`/`paused` → nada (o `pending`
   local já descreve).
3. **`current_period_end`:** max de `items.data[].current_period_end`.

Eventos `updated` por mudança irrelevante (metadata, cartão) reprocessam sem
efeito — o handler sincroniza estado, não incrementa nada.

## 3. Checkout e Portal

Dois controllers finos por escopo; a lógica comum (validações de plano, criação
da sessão) vive em `app/services/stripe_billing/` pra não duplicar.

**`#checkout`** — admin do dono:
- Conta: guard `EnsureCurrentAccountHelper` + admin; **403 se `account.agency_id`**
  (regra de negócio acima).
- Agência: `fetch_agency` + `ensure_agency_admin`, **PULANDO
  `ensure_agency_active`** — agência `pending_payment` (primeiro pagamento) e
  `suspended` (inadimplente voltando) PRECISAM alcançar o checkout. Mesmo skip
  do guard de suspensão no lado da conta. Furo A do desenho.
- Validações (422 + I18n): plano existe, `active?`, `stripe_price_id` presente,
  `plan_type` casa com o dono (`direct`↔Account, `agency`↔Agency).
- **Recusa com 422 se a assinatura já `grants_plan?`** — troca de plano é no
  portal, não no checkout (fecha o furo B: abrir checkout de plano caro e
  abandonar NÃO pode mudar limites).
- Cria/atualiza a `Subscription` **pending** do dono (owner é único — upsert do
  registro existente) e abre `Stripe::Checkout::Session` (`mode: 'subscription'`,
  `line_items: [{price:, quantity: 1}]`, `client_reference_id: subscription.id`,
  `customer: stripe_customer_id` se já houver, `subscription_data.metadata`
  com owner). Devolve `{ url: }`.

**`#portal`** — mesmos guards do checkout no respectivo escopo:
- 422 + I18n se `stripe_customer_id` ausente (nunca pagou → caminho é checkout).
- `Stripe::BillingPortal::Session.create(customer:, return_url:)` → `{ url: }`.
- Upgrade/downgrade/cancelar/cartão viram problema do Stripe; a volta chega
  por `customer.subscription.updated`/`deleted`.
- Pré-requisito operacional (não é código): ativar o Customer Portal e a
  feature `subscription_update` com os products no dashboard do Stripe.

`return_url`/`success_url`/`cancel_url`: raiz do app (`ENV['FRONTEND_URL']`).

## 4. `SubscriptionDashboard` (super admin)

Molde do `PlanDashboard`. `Field::Polymorphic` pro owner. `index/show/edit/update`
— **sem `new`/`destroy`** (não se inventa cobrança pelo painel). Form: `plan` e
`status` (escrita manual continua existindo pra cortesia/ajuste). Campos Stripe
read-only no show. Rota `resources :subscriptions, only: [...]` no namespace
super_admin + item de navegação.

## 5. `StripeWebhookEventDashboard` (super admin, read-only)

`index/show` apenas, filtros por status (`pending/processed/failed/ignored`).
É a única forma de enxergar `failed`/`ignored` sem console no EasyPanel — o
caso real: assinatura criada direto no dashboard do Stripe aparece como
`ignored` e o super admin liga na mão pelo SubscriptionDashboard.

## 6. I18n

Toda string nova em `en` E `pt_BR`: erros do checkout/portal
(`errors.subscriptions.*` — inglês idêntico ao que os specs assertam) e rótulos
do administrate pros dois dashboards.

## 7. Verificação (CI do espelho; Ruby não roda local)

Specs de request com payloads fixos e **assinatura real** gerada com
`Stripe::Webhook::Signature.generate_header` sobre o corpo — nada de stubar
`construct_event`, senão o spec não prova a verificação. ENV via convenção da
casa (`allow(ENV).to receive(:fetch).with('STRIPE_WEBHOOK_SECRET', nil)`).

Cobertura mínima:
- assinatura inválida → 401; segredo ausente → 401; JSON quebrado → 400
- mesmo `event_id` duas vezes → **uma mutação** (asserção no reload + count)
- órfão → 200 + linha `ignored`
- os 5 despachos, incluindo `updated` trocando plano por `stripe_price_id`
- checkout: 403 conta-filha de agência; 422 plano errado/`grants_plan?`;
  agência `pending_payment` ALCANÇA o checkout (o skip do guard funciona)
- portal: 422 sem `stripe_customer_id`
- chamadas à API do Stripe (checkout/portal session) stubadas nos specs de
  controller — o que se prova é o nosso contrato, não o SDK

## Fora de escopo (anotado de propósito)

- **UI** da seção de upgrade (dashboard da conta direta e painel da agência) —
  depois do backend verde.
- Proração, trial, cupom — Customer Portal/Stripe cuidam.
- Criar Subscription a partir de webhook (endpoint público não cria estado de
  cobrança).
- F7.5 (contador atômico de quota) — fase própria.
