# Prompt de retomada — executar a F8

> Colar o texto abaixo na próxima sessão. Substitui o
> `PROXIMA-SESSAO-f75-f8.md` (F7.5 foi executada e mergeada em 06/08).

---

Vamos executar a F8 do HDEV CRM (conexões de IA, catálogo e gate por plano).
O desenho e o plano JÁ ESTÃO PRONTOS E APROVADOS — nesta sessão é só executar.

Estado (2026-08-06, tudo na main com CI verde no espelho):
- F6 (limites), F7 (Stripe, PR #34), F7.5 (quota por contador atômico, PR #35)
  mergeadas. A F7.5 criou `ai_usage_counters` (incremento atômico no
  `after_create` de `AiUsageEvent`) e o `Ai::QuotaAlertJob`.
- **F8 desenhada e planejada em 06/08:**
  - Design (com as 3 decisões minhas): `docs/superpowers/specs/2026-08-06-f8-conexoes-ia-design.md`
  - Plano de implementação (10 tasks, código pronto): `docs/superpowers/plans/2026-08-06-f8-conexoes-ia.md`
  - Decisões: gate ESTRITO + seed (join vazio = nada; migration seeda planos
    existentes × catálogo inteiro); runtime DEGRADA com warn pro default do
    plano (`Ai::ModelNotAllowedError` herda de `QuotaExceededError` de
    propósito); credencial SÓ no super admin (`api_key` nullable, fallback
    `GlobalConfigService.load('ANTHROPIC_API_KEY')` até eu cadastrar no painel).
- Conta Stripe real: NÃO ligar — decisão minha, só depois da F8 (roteiro em
  `docs/superpowers/specs/2026-08-06-f7-stripe-testes-pendentes.md`).

O que fazer, nesta ordem:
1. Conferir pendências da F7.5:
   - Run 31116957671 do espelho: o job `lint` caiu por INFRA ("Set up job" do
     runner; rspec/vitest/baileys verdes) e o rerun ficou na fila no fim da
     sessão — `gh run view 31116957671 --repo solutionshdev-sudo/hdev-crm-ci`.
     Se ainda vermelho por infra, rerun de novo (`gh run rerun ... --failed`).
   - (Quando houver deploy) sanidade do backfill no terminal EasyPanel:
     contador vs `SUM(ai_usage_events)` por dono/mês.
2. Executar o plano da F8 com superpowers:executing-plans (execução INLINE —
   foi a escolha nas fases anteriores), task por task, commits pequenos.
3. Task 10: sync do espelho (eu dou o push), CI verde 4/4, artifact `schema`
   commitado, e me passar o comando do merge (`gh pr merge` é bloqueado pra ti).

Restrições do ambiente (valem sempre):
- Ruby e Docker NÃO rodam nesta máquina; specs só no CI do espelho público
  `solutionshdev-sudo/hdev-crm-ci`. JS roda local (`corepack pnpm exec vitest/eslint`)
  — Task 8 do plano verifica local ANTES de empurrar.
- Sync do espelho: staging CURTO `C:\Users\hdev\AppData\Local\Temp\hdev-ci-sync`
  via `git archive <branch> hdevCRM baileys-service .github .gitignore VERSION | tar -x`
  (não `cp`), `git init -b main`, restaurar bits 100755 (16 arquivos), commit
  `sync:`, e EU dou o `git push --force <url> HEAD:refs/heads/main` conferindo
  `git log --oneline -1` antes.
- `jq` standalone não existe — usar `--jq` do `gh`. PowerShell 5.1 mutila
  `-m`/`--body` longos — usar `-F`/`--body-file`. Cuidado com crases em aspas
  duplas no bash (command substitution come o texto).
- Checks do PR no repo privado SEMPRE vermelhos (billing) — quem valida é o espelho.
- Texto visível ao usuário = chave I18n em `en` E `pt_BR` (inglês idêntico ao
  que os specs assertam). Nunca reativar `enterprise/`.

Armadilhas anotadas (não repetir):
- `create_or_find_by!` NÃO com validação de uniqueness — é `find_or_create_by!`
  + rescue `RecordNotUnique`.
- `show_exceptions = true` no test env: rota inexistente = 404, não RoutingError.
- API de gem: WebFetch na doc oficial antes de escrever (o plano da F8 já tem
  esse passo pro `Anthropic::BedrockMantleClient`, Task 6 Step 1).
- Rubocop: classe nova em estilo compacto (`class Ai::X` — o aninhado do
  reply_job está congelado no todo); `Metrics/MethodLength` máx 19;
  `Layout/MultilineMethodCallIndentation` em matcher encadeado de spec.
- Seeds de migration em SQL puro, nunca via model; nenhum seed grava valor
  cifrado (a conexão nasce com api_key NULL).
- O seed cartesiano de `plan_ai_models` não aparece no CI (banco de teste migra
  sem planos) — prova é SELECT em produção no deploy.

Começa lendo o design e o plano da F8, conferindo a pendência do item 1, e me
diz por qual task vai começar.
