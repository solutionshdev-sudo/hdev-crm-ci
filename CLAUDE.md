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
- [ ] gh (GitHub CLI) — opcional
- [ ] playwright — só quando for usar render de carrossel
