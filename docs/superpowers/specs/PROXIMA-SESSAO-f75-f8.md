# Prompt de retomada — próxima sessão (F7.5 + F8)

Copiar o bloco abaixo inteiro na próxima sessão.

---

Vamos continuar a camada comercial do HDEV CRM (plano em `plano-fases-6-11.md`
na raiz). A F7 (Stripe) foi mergeada na main em 06/08 (`d019e79`, PR #34) com
CI verde 4/4 no espelho — 6452 exemplos, 0 falhas.

**Estado atual e por que a ordem é essa:**

- F6 (limites de plano) e F7 (Stripe) estão na main. O `Plan::LimitEnforcer`
  responde "pode?" e o `Webhooks::StripeController` dirige
  `Subscription#activate!/#mark_past_due!/#cancel!`.
- **A conta Stripe ainda NÃO foi criada de propósito.** Decisão minha: só vou
  criar a conta, pegar a chave e rodar os testes de API *depois que os planos
  estiverem definitivos* — e quem fecha o que um plano contém é a F8, que
  adiciona o gate de modelos de IA por plano (`plan_ai_models`). Cadastrar os
  products no Stripe antes disso significaria refazer. Então: **não me peça
  pra ligar o Stripe nesta sessão.** O roteiro pronto pra quando chegar a hora
  está em `docs/superpowers/specs/2026-08-06-f7-stripe-testes-pendentes.md`.

**O que fazer, nesta ordem:**

**1. F7.5 — quota por contador atômico** (fase curta, alto retorno, plano §F7.5).
Hoje `Ai::QuotaService#account_usage` (`hdevCRM/app/services/ai/quota_service.rb:62`)
e `#agency_usage` (`:68`) rodam `SUM(total_tokens)` sobre `ai_usage_events` a
cada chamada, e o `Ai::AnthropicService` consulta `exceeded?`
(`anthropic_service.rb:30`) a cada volta do ToolLoop — até 8 por resposta. Pior:
`check_thresholds!` (`quota_service.rb:47`) dispara o mailer **dentro da
request** (`anthropic_service.rb:102`). Mudar para:
- migration `create_ai_usage_counters` (owner polimórfico Account|Agency,
  `period_start date`, `tokens bigint`, `cost_cents bigint`, unique
  `(owner_type, owner_id, period_start)`);
- `AiUsageEvent after_create` incrementando via `update_counters` — **mesmo
  padrão atômico já usado em `AiCreditEvent#record!`
  (`hdevCRM/app/models/ai_credit_event.rb:38`)**, reusar, não inventar;
- `account_usage`/`agency_usage` lendo o contador;
- `check_thresholds!` virando `Ai::QuotaAlertJob` (Sidekiq), mantendo o
  cooldown Redis de 24h como está.
Verificação: spec comparando contador vs. `SUM()` depois de N eventos, e spec
provando que o mailer não é chamado de forma síncrona.
**Tem migration** — baixar o artifact `schema` do CI e commitar o `db/schema.rb`.

**2. F8 — conexões de IA, catálogo e gate por plano** (plano §F8, é a fase
grande: 4 tabelas). Antes de escrever qualquer código, **me apresente o desenho
e confirme comigo** — em especial: como o `Ai::ModelResolver` resolve
`canonical_id` → `(connection, provider_model_id)` validando o plano da conta,
o que acontece com conta cujo plano não libera nenhum modelo, e como a
migração dos dados atuais (modelo hoje é string livre; preço hoje é a constante
`Ai::Pricing::PRICES` em `lib/ai/pricing.rb:6`) acontece sem quebrar as contas
existentes. Reusar o padrão de criptografia do repo
(`encrypts :api_key if HdevCrm.encryption_configured?`, igual a
`channel/telegram.rb:21`) e o shared example
`spec/support/examples/encrypted_external_credential_examples.rb`.

**Restrições do ambiente (do CLAUDE.md, valem sempre):**

- Ruby e Docker NÃO rodam nesta máquina. Todo spec roda no CI do espelho
  público `solutionshdev-sudo/hdev-crm-ci`; **eu (Harvey) dou o push** do
  staging. Montar o commit de sync num caminho CURTO tipo
  `C:\Users\hdev\AppData\Local\Temp\hdev-ci-sync` usando `git archive | tar`
  (não `cp` — o scratchpad estoura o MAX_PATH).
- `jq` standalone não existe aqui — usar o `--jq` do próprio `gh`.
- PowerShell 5.1 mutila aspas em `git commit -m` com texto longo: usar
  `-F arquivo`. **E cuidado com crases dentro de aspas duplas no bash** — o
  shell expande como command substitution e come o texto (aconteceu na F7 ao
  escrever o diário).
- Checks do PR no repo privado SEMPRE vermelhos (billing, falham em ~15s sem
  log) — não é falha de teste, quem valida é o espelho.
- **`gh pr merge` está bloqueado pra você nesta sessão** — me passe o comando
  que eu rodo.
- Texto novo visível ao usuário sempre com chave I18n em `en` E `pt_BR`.
- Nunca reativar `enterprise/` nem recuperar aquele código do histórico.

**Armadilhas anotadas do repo (não repetir):**

- `inboxes_controller` está em 175/175 no `Metrics/ClassLength` — se encostar,
  já vai extraindo.
- `create_or_find_by!` NÃO serve quando o model tem validação de uniqueness
  (cria primeiro e estoura `RecordInvalid`); é `find_or_create_by!` com rescue
  de `RecordNotUnique`.
- `show_exceptions = true` no test env: rota inexistente vira 404, spec que
  espera `ActionController::RoutingError` falha.
- Quando precisar da API de uma gem ou de um provider, **ler a doc oficial**
  (WebFetch) em vez de chutar a assinatura — na F7 três campos do Stripe
  tinham mudado de lugar e os exemplos antigos quebrariam calado.

Começa lendo o plano e o estado atual, e me diz o que você vai fazer na F7.5
antes de escrever código.
