# F7 Stripe — testes pendentes (dependem da conta/chave do Stripe)

> O código da F7 está coberto por specs no CI (webhook com assinatura real,
> idempotência, checkout/portal, painéis). O que está AQUI só dá pra provar
> com uma conta Stripe de verdade — fazer quando decidir conectar a API.
> Ordem pensada pra rodar de cima pra baixo em modo teste (chave `sk_test_`).

## 0. Pré-requisitos (uma vez, no dashboard do Stripe em modo teste)

1. Criar conta Stripe (ou usar existente) e pegar as chaves em
   Developers → API keys.
2. **EasyPanel**: setar no container do Rails:
   - `STRIPE_SECRET_KEY=sk_test_...`
   - `STRIPE_WEBHOOK_SECRET=whsec_...` (sai do passo 3)
   - conferir que `FRONTEND_URL` aponta pro domínio real (success/cancel/return
     url do checkout e do portal usam ele)
3. Developers → Webhooks → Add endpoint:
   - URL: `https://<dominio>/webhooks/stripe`
   - Eventos (exatamente estes 5): `checkout.session.completed`,
     `invoice.paid`, `invoice.payment_failed`,
     `customer.subscription.updated`, `customer.subscription.deleted`
   - Copiar o "Signing secret" (whsec_...) pro env do passo 2. Rebuild.
4. Products → criar 1 product por plano, com preço recorrente (mensal).
   Copiar cada `price_...`.
5. `/super_admin/plans`: preencher `stripe_price_id` de cada plano com o
   price correspondente. Tipo do plano tem que casar (direct pra conta,
   agency pra agência) — o checkout recusa mismatch.
6. Settings → Billing → Customer portal: ativar; em Features, ligar
   **subscription update** e selecionar os products permitidos (é o que
   habilita upgrade/downgrade no portal). Salvar a configuração default.

## 1. Sanidade do endpoint (sem pagar nada)

- [ ] `curl -X POST https://<dominio>/webhooks/stripe -d '{}'` → **401**
      (sem assinatura). Se der 404, a rota não subiu; se der 200, o
      STRIPE_WEBHOOK_SECRET não está setado (o controller fecha com 401
      quando falta — investigar antes de seguir).
- [ ] Dashboard do Stripe → Webhooks → endpoint → "Send test webhook" →
      `invoice.paid` → deve responder **200** e aparecer uma linha
      **Ignorado** em `/super_admin/stripe_webhook_events` (o payload de
      teste não casa com assinatura local — é o comportamento esperado).

## 2. Checkout ponta a ponta — conta direta

- [ ] Criar conta direta de teste (sem agência) com um admin.
- [ ] `POST /api/v1/accounts/:id/subscription/checkout` com
      `{ "plan_id": <plano direct> }` (token do admin) → 200 com `url`.
- [ ] Abrir a `url`, pagar com cartão de teste `4242 4242 4242 4242`
      (validade futura, CVC qualquer).
- [ ] Conferir em `/super_admin/stripe_webhook_events`:
      `checkout.session.completed` e `invoice.paid` **Processados**.
- [ ] Conferir em `/super_admin/subscriptions`: assinatura **Ativa**, com
      customer/subscription id e fim do período preenchidos.
- [ ] Replay: no dashboard do Stripe, reenviar o `checkout.session.completed`
      já entregue → 200 e NADA muda (idempotência em produção).

## 3. Checkout ponta a ponta — agência

- [ ] Agência em `pending_payment` com admin: repetir o fluxo do §2 com
      plano `agency` em `POST /api/v1/agencies/:id/subscription/checkout`.
- [ ] Após o webhook: agência volta a `active` (o `activate!` reativa o dono)
      e o painel dela abre normalmente.

## 4. Portal — troca de plano e cancelamento

- [ ] `POST .../subscription/portal` → 200 com `url`; abrir logado como o
      customer de teste.
- [ ] Trocar de plano no portal → `customer.subscription.updated` chega,
      linha Processado, e o **plano local troca sozinho** em
      `/super_admin/subscriptions` (é o sync por `stripe_price_id`).
- [ ] Cancelar (imediato, não "ao fim do período", pra ver o efeito na hora)
      → `customer.subscription.deleted` chega, assinatura **Cancelada** e o
      dono **suspenso**.
- [ ] Voltar: novo checkout na conta suspensa (tem que ser alcançável mesmo
      suspensa — é desenho, não bug) → paga → reativa.

## 5. Inadimplência (simulada)

- [ ] No Stripe de teste: trocar o cartão do customer por
      `4000 0000 0000 0341` (falha ao cobrar) e forçar um invoice (avançar
      o test clock ou "charge customer" manual).
- [ ] `invoice.payment_failed` chega → assinatura **Inadimplente** — e o
      acesso CONTINUA (grants_plan? aceita past_due; suspensão só no deleted).

## 6. Conferências finais

- [ ] `db:migrate:status` no container: nada pendente (F7 não tem migration,
      é só sanidade de deploy).
- [ ] Log do Rails sem `[STRIPE] webhook 401` inesperado (401 esporádico =
      alguém batendo sem assinatura; enxurrada = secret errado).
- [ ] Cada evento dos testes acima tem exatamente UMA linha na tabela
      (o retry do Stripe não duplicou nada).

## Fora da F7 (lembretes)

- UI de "Planos/Upgrade" no dashboard da conta direta e no painel da agência
  (hoje o checkout/portal é só API) — planejar junto com o front da F8+.
- Conta-filha de agência NUNCA vê billing nosso (403 `agency_managed`) — se
  aparecer demanda de cobrança da agência pros clientes dela, é feature nova,
  não é ligar o Stripe pra ela.
