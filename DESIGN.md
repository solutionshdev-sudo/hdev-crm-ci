---
name: Hdev CRM
description: Design system "next" do Hdev CRM — verde Hdev sobre neutros slate, claro/escuro por CSS vars, white-label por domínio
colors:
  brand-vivid: "#00D488"
  brand-solid: "#00875A"
  brand-solid-hover: "#00774F"
  accent-text-light: "#006946"
  accent-text-dark: "#00D488"
  app-bg-light: "#F6FEFA"
  app-bg-dark: "#081610"
  neutral-bg-light: "#FCFCFD"
  neutral-bg-dark: "#111113"
  neutral-surface-light: "#F9F9FB"
  neutral-surface-dark: "#18191B"
  neutral-border-light: "#D9D9E0"
  neutral-border-dark: "#363A3F"
  text-strong-light: "#1C2024"
  text-strong-dark: "#EDEEF0"
  text-muted-light: "#60646C"
  text-muted-dark: "#B0B4BA"
  danger: "#E54666"
  warning: "#FFC53D"
typography:
  headline:
    fontFamily: "Inter, -apple-system, system-ui, sans-serif"
    fontSize: "1.5rem"
    fontWeight: 700
    lineHeight: 1.25
  title:
    fontFamily: "Inter, -apple-system, system-ui, sans-serif"
    fontSize: "1.125rem"
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: "Inter, -apple-system, system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "Inter, -apple-system, system-ui, sans-serif"
    fontSize: "0.75rem"
    fontWeight: 500
    lineHeight: 1.4
rounded:
  sm: "6px"
  md: "8px"
  lg: "12px"
  full: "9999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.brand-solid}"
    textColor: "#FFFFFF"
    rounded: "{rounded.md}"
    padding: "8px 16px"
  button-primary-hover:
    backgroundColor: "{colors.brand-solid-hover}"
  nav-item:
    textColor: "{colors.text-muted-light}"
    rounded: "{rounded.md}"
    padding: "6px 8px"
---

# Design System: Hdev CRM

## Overview

**Creative North Star: "A Ferramenta que Desaparece"**

Interface de trabalho tech e direta: neutros slate com leve frieza, muito
respiro, e um único acento — o verde Hdev — usado com parcimônia cirúrgica.
A estética segue o produto (dashboard), nunca o contrário: nada de gradientes
chamativos, sombras raras, contraste de fundo no lugar de elevação. O sistema
inteiro vive em CSS custom properties de 12 passos (escala Radix) que flipam
com a classe `.dark` no elemento raiz — todo componente novo nasce nos dois
temas ao mesmo tempo.

Anti-referência confirmada: o visual Chatwoot (azuis `#2781F6`/`#1F93FF`) é
proibido — denuncia a origem do fork.

**Key Characteristics:**
- Um acento só (verde Hdev), neutros slate pra todo o resto
- Claro/escuro por CSS vars (`.dark` no root), nunca por página
- Densidade de ferramenta: tabelas e painéis compactos, tipografia contida
- Bordas 1px discretas no lugar de sombras
- White-label: o acento acompanha a marca da agência via tokens

## Colors

Neutros slate de 12 passos + uma rampa de acento verde de 12 passos, ambas com
variante clara e escura; os semânticos ruby (erro) e amber (aviso) completam o
vocabulário.

### Primary
- **Verde Hdev vivo** (#00D488, token `--blue-8` claro / `--blue-11` escuro):
  acentos SEM texto em cima — bordas fortes, foco, ícones, brilhos, toggles.
  Contraste com branco é 1,95:1 — nunca carregar texto.
- **Verde sólido** (#00875A, token `--blue-9` nos dois temas): fundo de CTA e
  botão primário; aguenta texto branco (4,55:1 AA). Hover: #00774F (`--blue-10`
  claro) / #009C67 (escuro).
- **Texto de acento** (#006946 claro / #00D488 escuro, token `--blue-11`):
  links e texto verde — a rampa anda em direções opostas por tema.

### Neutral
- **Fundo de app** (`--slate-1`: #FCFCFD claro / #111113 escuro): fundo base
  das páginas.
- **Superfície secundária** (`--slate-2`: #F9F9FB / #18191B): sidebar,
  toolbars, painéis — a "segunda camada neutra".
- **Fundo de componente/hover** (`--slate-3..4`): hover de linha, item ativo.
- **Bordas** (`--slate-6` sutil, `--slate-7` padrão): divisores e contornos.
- **Texto silencioso** (`--slate-11`: #60646C / #B0B4BA): labels, meta.
- **Texto forte** (`--slate-12`: #1C2024 / #EDEEF0): títulos e conteúdo.

### Semantic
- **Erro/destrutivo** (`--ruby-9..11`): ações de excluir, validação.
- **Aviso** (`--amber-*`), **info** usa o próprio acento verde.

### Named Rules
**The Agency Override Rule.** Acento em telas novas usa SEMPRE os tokens
`n-blue-9/10/11` (CSS vars que o servidor sobrescreve por domínio via
`Agency#brand_rgb`) — nunca `n-brand`/`n-brandVivid` nem hex fixo. Quem usa o
token ganha a marca da agência de graça; quem usa hex quebra o white-label.

**The No-Text-On-Vivid Rule.** #00D488 e #00FF9F jamais recebem texto por
cima; texto branco só sobre o sólido #00875A (passo 9).

**The No-Chatwoot-Blue Rule.** #2781F6 e #1F93FF são proibidos em qualquer
superfície.

## Typography

**Display/Body Font:** Inter (fallback -apple-system, system-ui, sans-serif)

**Character:** uma família só, afinada pra UI de produto: títulos 700, corpo
400–500, sem fonte display. Escala contida (ratio ~1.125–1.2) — mais passos,
menos drama.

### Hierarchy
- **Headline** (700, 1.5rem): título de página.
- **Title** (600, 1.125rem): seções e cards.
- **Body** (400, 0.875rem / 14px): conteúdo, células de tabela.
- **Label** (500, 0.75rem / 12px): meta, cabeçalho de tabela, badges.

## Layout

Grade de 4px (escala Tailwind). Sidebar fixa de 224px (`w-56`) com conteúdo
fluido ao lado; páginas de conteúdo com padding 16–24px. Densidade de
ferramenta: linhas de tabela ~44px, formulários em coluna única com labels em
cima. Responsividade estrutural (colapsar sidebar), não tipografia fluida.

## Elevation & Depth

Sistema essencialmente plano: profundidade por camadas tonais
(`--slate-1` → `--slate-2` → `--slate-3`), bordas 1px, e sombra apenas em
overlays (dropdown/modal). Preferir contraste de fundo a sombra.

## Shapes

Cantos suavemente arredondados: 8px (`rounded-lg`) em botões, inputs e itens de
navegação; 12px (`rounded-xl`) em cards e containers; pill (`rounded-full`) em
badges, avatares e switches. Bordas 1px em `--slate-6/7`.

## Components

### Buttons
- **Shape:** 8px de raio; altura ~32–36px; padding 8px 16px.
- **Primary:** fundo verde sólido `n-blue-9` (#00875A), texto branco,
  weight 500; hover `n-blue-10`.
- **Secondary/Ghost:** texto `--slate-11`, fundo transparente, hover
  `--slate-3`; borda 1px `--slate-7` na variante outline.
- **Destructive:** `--ruby-9` sólido ou texto `--ruby-11` (ghost).
- **Focus:** anel `--blue-8` (verde vivo), offset 1px.
- **Estados obrigatórios:** default, hover, focus-visible, active, disabled
  (opacidade 50%, sem hover).

### Inputs / Fields
- **Style:** fundo `--slate-1`, borda 1px `--slate-7`, raio 8px, padding
  8px 12px, texto `--slate-12`, placeholder `--slate-10`.
- **Focus:** borda `--blue-8` + anel suave.
- **Error:** borda `--ruby-9`, mensagem `--ruby-11`.

### Navigation (sidebar)
- **Style:** superfície `--slate-2`, borda direita 1px `--slate-6`, itens
  raio 8px com ícone 16px + label 14px em `--slate-11`.
- **Hover:** fundo `--slate-3`, texto `--slate-12`.
- **Active:** fundo `--slate-4` (ou `--blue-3`), texto `--blue-11`, weight 500.

### Cards / Containers
- **Corner:** 12px; fundo `--slate-1` sobre página `--slate-2` (ou vice-versa);
  borda 1px `--slate-6`; padding 16–24px; sem sombra em repouso.

### Tables
- Cabeçalho: label 12px/500 em `--slate-11`, fundo `--slate-2`, borda inferior
  `--slate-6`. Linhas: 14px em `--slate-12`, hover `--slate-2/3`, divisores
  `--slate-4`; ações à direita (Editar em `--blue-11`, Excluir em `--ruby-11`).

### Switch (tema)
- Pill 36×20px: trilho `--slate-6` (off) / `--blue-9` (on), thumb branco 16px
  com deslize de 150ms; ícone opcional 12px dentro do thumb.

## Do's and Don'ts

### Do:
- **Do** usar classes Tailwind `n-*` (`bg-n-slate-2`, `text-n-slate-12`,
  `bg-n-blue-9`...) — elas resolvem pra CSS vars e flipam com `.dark` de graça.
- **Do** definir os dois temas no mesmo commit de qualquer tela nova.
- **Do** usar `--blue-11` pra texto verde e `--blue-9` pra fundo com texto
  branco, respeitando a direção invertida da rampa no escuro.
- **Do** transições de 150–250ms só pra estado (hover, focus, abrir/fechar).

### Don't:
- **Don't** hex fixo de marca em tela nova — quebra o override por agência.
- **Don't** texto sobre #00D488/#00FF9F (1,95:1, ilegível).
- **Don't** azuis do Chatwoot (#2781F6, #1F93FF), em nenhuma hipótese.
- **Don't** sombras decorativas, gradientes chamativos ou motion de decoração.
- **Don't** cinza puro (#808080-likes) — os neutros são slate, levemente frios.
