# Harvey — HDEV CRM

> Workspace de um dev solo construindo o **HDEV CRM**: um CRM white-label
> (fork do Chatwoot) vendido pra agências. O `/instalar` adaptou esse
> molde à realidade do negócio.

## Regras de operação do sistema

Válidas em qualquer perfil — não remover esse import.

@_sistema/regras.md

## O que é esse workspace

Operação de produto do HDEV CRM. Aqui vive o código da plataforma
(`hdevCRM/`, fork do Chatwoot em processo de white-label), a memória do
negócio e as skills do HDEV.

**Estrutura de pastas:**
- `_memoria/` — quem sou, como falo, o que tá em foco
- `identidade/` — cores, fontes, logo, padrão visual da marca HDEV CRM
- `hdevCRM/` — o código da plataforma (fork do Chatwoot)
- `baileys-service/` — microserviço Node do WhatsApp não-oficial (Baileys); conversa com o Rails por HTTP interno + webhook HMAC
- `_sistema/` — núcleo de regras do HDEV (não sobrescrever)
- `templates/`, `.claude/skills/` — moldes e skills do sistema
- `PRODUCT.md` / `DESIGN.md` (raiz) — contexto de produto e design system
  oficial da plataforma (tokens `n-*`, regras de acento white-label). Toda tela
  nova do produto segue o `DESIGN.md`; a skill `impeccable` (com detector de
  design via hook) usa os dois como fonte de verdade

## Quem sou

Sou o Harvey, dev. Toco sozinho. Estou construindo o HDEV CRM pra vender
como white-label pra agências — elas usam a minha plataforma pra atender
os clientes delas com a marca delas (ou a minha, conforme o plano).

## Produto

- **HDEV CRM** — CRM / plataforma de atendimento white-label, fork do
  Chatwoot. Cliente-alvo: agências que revendem pros próprios clientes.
- Estrutura de planos de revenda: em definição.

## Regras do sistema

- O código da plataforma fica em `hdevCRM/`. Antes de mexer nele, ler o
  status da migração em `_memoria/de-chatwoot.md`.
- Rebrand Chatwoot → Hdev CRM: **remover toda menção**, inclusive
  identificadores internos e a superfície JS do widget, sem
  retrocompatibilidade. O fork segue vida própria (não puxa updates do
  upstream). Renomear com cuidado: Zeitwerk exige arquivo e constante
  casados, e há resoluções por string que busca-e-substitui não pega.
  Exceções conhecidas em `_memoria/de-chatwoot.md`.
- **Nunca reativar o diretório `enterprise/`.** A licença dele exige
  assinatura paga para uso em produção e proíbe revenda — o oposto do
  modelo de negócio. O núcleo é MIT e pode ser vendido; nunca alterar
  o arquivo `LICENSE`.
- Nunca comitar `.env` nem chaves/tokens (ver seção Segurança nas regras).
- **Idioma:** o locale padrão do app é `pt_BR` (`config.i18n.default_locale`
  no `application.rb`); os specs rodam em `:en` (fixado no `test.rb`). Texto
  novo visível ao usuário nunca é hardcoded — sempre chave I18n com valor em
  `en` E `pt_BR` (o inglês dos arquivos `*_errors`/`mailers` precisa ficar
  idêntico ao que os specs assertam). Exceção: corpos de e-mail `.liquid`
  são pt-BR direto (Liquid não acessa I18n).

## Ferramentas / ambiente

- [x] node 24
- [x] git 2.55 — repo `solutionshdev-sudo/hdev-crm` no GitHub, `main` sincronizada
- [x] gh (GitHub CLI) — autenticado; é como se acompanha o CI daqui
- [x] pnpm 10.2 — via `corepack pnpm` (não está no PATH direto)
- [ ] playwright — só quando for usar render de carrossel
- [ ] **ruby / bundler — NÃO instalados nesta máquina**
- [ ] **docker — NÃO instalado nesta máquina**

**Consequência prática — a verificação tem três níveis, não um:**

1. **JS roda aqui.** `corepack pnpm exec vitest run <caminho>` e
   `corepack pnpm exec eslint --fix <caminho>` fecham o ciclo em segundos. Use
   isso antes de empurrar — não gaste rodada de CI com erro de formatação.
   Instalar as dependências exige `corepack pnpm install --ignore-scripts`: o
   `prepare` do `package.json` roda `husky install`, herdado do upstream onde o
   app era a raiz do repo, e aqui o `.git` fica um nível acima de `hdevCRM/`.
2. **Ruby roda no CI.** Nada de Rails executa localmente — nem `rspec`, nem
   `db:migrate`, nem inspecionar o código de uma gem instalada. O GitHub Actions
   é o interpretador Ruby do projeto (ver seção abaixo).
3. **O produto se verifica no servidor.** Migration aplicada, integração com o
   WhatsApp, chave da Anthropic: só o terminal do container no EasyPanel responde.

Quando precisar da API de uma gem, ler a documentação oficial (WebFetch) em vez
de chutar a assinatura.

## CI (`.github/workflows/ci.yml`)

Na raiz do repo, fora de `hdevCRM/`. Três jobs: `rspec`, `lint`
(rubocop + eslint) e `vitest`. Roda em push na `main`, em PR e sob demanda.

- **É o único interpretador Ruby do projeto.** A imagem de produção apaga
  `spec/`, então rodar rspec no EasyPanel não é opção.
- **A suíte nunca terminou de rodar, nenhuma vez.** Ela trava: cerca de 10-11 min
  depois do início do rspec o processo para de escrever no log e fica vivo, parado,
  até o `timeout-minutes: 90` matar o job. Reproduzido em dois runs, com a mesma
  última linha nos dois. Qualquer estimativa de "a suíte leva X minutos" é chute —
  não existe medição. Diagnóstico aberto desde 28/07.
- **`concurrency: cancel-in-progress: true`** — todo push na `main` executa o run
  anterior. Um `cancelled` no histórico quase sempre é isso, não falha de teste;
  a exceção é o run que morre exatamente em 90 min, que é o timeout. Olhar a
  duração antes de concluir qualquer coisa.
- **`workflow_dispatch` aceita um `spec_path`** — use pra iterar num arquivo só.
  O valor é interpolado **sem aspas** no comando, de propósito, então ele engole
  qualquer flag do rspec e não só caminho: `--format documentation` roda a suíte
  inteira imprimindo o nome de cada exemplo antes de executá-lo. É assim que se
  acha spec que trava, sem precisar commitar nada.
- **Regenera o `db/schema.rb` de graça:** `dump_schema_after_migration` só está
  desligado em production/staging, então o `db:migrate` em `RAILS_ENV=test`
  redumpa o schema, publicado como artifact `schema`. Baixar e commitar a mão
  depois de cada lote de migration — o workflow não escreve na `main`.
- **`.rubocop_todo.yml`** congela a dívida de estilo herdada (67 ofensas, 33
  autocorrigíveis com `rubocop -a` no container). O gate vale pra código novo.
