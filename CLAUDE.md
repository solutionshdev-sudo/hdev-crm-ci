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
- `_sistema/` — núcleo de regras do HDEV (não sobrescrever)
- `templates/`, `.claude/skills/` — moldes e skills do sistema

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
  contexto de rebrand em `_memoria/estrategia.md`.
- Rebrand Chatwoot → HDEV CRM: trocar só a marca **visível ao usuário**.
  Não renomear identificadores internos de código (classes, módulos,
  pacotes npm `@chatwoot/*`, tabelas, feature flags, nomes de serviço de
  deploy) sem verificação — quebra o sistema.
- Nunca comitar `.env` nem chaves/tokens (ver seção Segurança nas regras).

## Ferramentas / ambiente

- [x] node 24
- [ ] git — **instalar antes de usar /salvar**
- [ ] gh (GitHub CLI) — opcional
- [ ] playwright — só quando for usar render de carrossel
