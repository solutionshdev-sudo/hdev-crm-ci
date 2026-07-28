# Identidade visual

> Como a marca aparece em tudo que o HDEV gera.
> As skills de conteúdo, carrossel e post leem esse arquivo antes de criar qualquer visual.
> Edite quando a marca evoluir.

---

## Cores

- **Fundo principal:** `#0F172A` (azul-escuro quase preto — o mesmo do texto "CRM" no logo)
- **Cor de destaque / CTA:** `#00875A` (verde sólido — aguenta texto branco, contraste 4,55:1 AA).
  O verde vivo da marca `#00D488` é para acentos SEM texto em cima: bordas, ícones,
  gráficos, brilhos. No ícone/logo usa-se `#00FF9F`.
- **Texto principal:** `#0F172A` sobre fundo claro; `#F6FEFA` sobre fundo escuro
- **Fundo alternativo / cards:** `#EBFBF3` (verde muito pálido) no claro; `#0C1E16` no escuro
- **Cor proibida:** `#2781F6` e `#1F93FF` (os azuis do Chatwoot — nunca usar; denunciam a origem do fork)

### Rampa completa (a mesma dos tokens `--blue-1..12` do produto)

| Passo | Claro | Escuro | Uso |
|---|---|---|---|
| 1 | `#F6FEFA` | `#081610` | fundo de app |
| 2 | `#EBFBF3` | `#0C1E16` | fundo sutil |
| 3 | `#D4F7E7` | `#063021` | fundo de componente |
| 4 | `#BAF0D9` | `#003E2A` | hover |
| 5 | `#9CE7C8` | `#004C34` | ativo |
| 6 | `#78D9B2` | `#005C3F` | borda sutil |
| 7 | `#49C896` | `#02704C` | borda |
| 8 | `#00D488` | `#007A52` | **marca pura** (claro): borda forte, foco, toggle |
| 9 | `#00875A` | `#00875A` | **sólido/CTA** — texto branco ✅ |
| 10 | `#00774F` | `#009C67` | hover do sólido |
| 11 | `#006946` | `#00D488` | texto de acento (**marca pura** no escuro) |
| 12 | `#083826` | `#B7F5D9` | texto de alto contraste |

---

## Tipografia

- **Títulos e destaques:** Inter (a mesma do produto)
- **Corpo, subtítulos e botões:** Inter
- **Peso do título:** 700 (bold); corpo 400-500

---

## Estilo geral

Tech e direto: fundos escuros `#0F172A`, acentos em verde vivo, muito espaço em
branco/escuro, sem gradientes chamativos. A estética segue o produto (dashboard
do Hdev CRM), não o contrário.

---

## Elementos-chave

- Bordas: 1px, discretas (`#78D9B2` no claro, `#005C3F` no escuro)
- Border-radius dos cards: 12-14px (o produto usa `rx:7` num tile de 32 = ~22%)
- Botões: fundo `#00875A`, texto branco, radius 10-14px; hover `#00774F`
- Sombras: suaves e raras; preferir contraste de fundo a sombra

---

## O que NUNCA fazer

- Texto branco sobre `#00D488` ou `#00FF9F` (contraste 1,95:1 — ilegível)
- Usar os azuis do Chatwoot (`#2781F6`, `#1F93FF`)
- Verde sobre verde sem checar contraste (mínimo AA 4,5:1 para texto)

---

## Logo

- **Arquivo:** `hdevCRM/public/brand-assets/logo.svg` (chevrons `#00D488` + "CRM" `#0F172A`)
- **Versão pra fundo escuro:** `hdevCRM/public/brand-assets/logo_dark.svg`
- **Ícone/thumbnail:** `hdevCRM/public/brand-assets/logo_thumbnail.svg` (chevrons `#00FF9F`)
- **Favicon/tile:** chevrons verdes sobre tile `#0F172A` arredondado (gerados em `hdevCRM/public/`)
- **Onde usar:** slide final do carrossel (CTA), header de propostas, slides de apresentação
- **Tamanho sugerido:** largura entre 120-200px nos HTMLs

---

## Observações adicionais

- A paleta do produto vive em `hdevCRM/app/javascript/dashboard/assets/scss/_next-colors.scss`
  (tokens `--blue-*`, que apesar do nome legado valem VERDE) e em `hdevCRM/theme/colors.js`
  (`brand` / `brandVivid`). Mudou a marca? Mudar lá e aqui juntos.
- O design system do **produto** (pra código: componentes, regras nomeadas,
  claro/escuro) está documentado em `DESIGN.md` na raiz do workspace — as
  skills de código leem de lá. Mudou a marca? Atualizar os três juntos.

### Regra de acento no white-label (não esquecer)

Numa tela nova, **acento sempre em `n-blue-9/10/11`, nunca em `n-brand`**:

- `n-brand` (#00875A) e `n-brandVivid` (#00D488) são **hex fixos** no
  `theme/colors.js` — não seguem a marca da agência.
- `n-blue-9/10/11` são CSS vars que o servidor **sobrescreve por domínio
  customizado** (`app/views/layouts/vueapp.html.erb`, a partir de
  `Agency#brand_rgb`). Quem usa esses tokens acompanha a cor da agência de graça.
- A rampa anda em **direções opostas por tema**: sobre fundo claro o 10/11
  escurecem; sobre fundo escuro clareiam (`brand_rgb` com percentual negativo).
  Inverter isso joga o texto de acento pra ~2:1 de contraste no escuro.
- O botão primário do `components-next/button/Button.vue` ainda usa `bg-n-brand`
  fixo — por isso as telas de auth forçam `!bg-n-blue-9`. Trocar no componente
  conserta o app inteiro, mas mexe em toda a UI: é tarefa própria.
- E-mails transacionais usam `#00875A` hardcoded em
  `hdevCRM/app/views/layouts/mailer/base.liquid` e `.../devise/mailer/_confirmation_body.html.erb`.
