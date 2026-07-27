# Product

<!-- impeccable:product-schema 1 -->

<!-- Escrito a partir de fatos confirmados pelo Harvey em CLAUDE.md,
     _memoria/ e identidade/design-guide.md (sem entrevista nova; itens
     marcados [inferido] são hipótese minha, não fato confirmado). -->

## Platform

web

## Users

- **Agências** (cliente pagante): revendem a plataforma pros próprios clientes
  com a marca delas (ou a da Hdev, conforme o plano). Usam o dashboard de
  atendimento no dia a dia.
- **Clientes das agências**: atendidos via canais (WhatsApp Baileys/Cloud,
  Instagram, e-mail, chat ao vivo etc.).
- **Harvey (super admin)**: dev solo, dono da operação. Usa o Console do Super
  Admin pra administrar contas, agências, usuários e a saúde da instância.
  [inferido] Uso em desktop, sessões curtas e objetivas de administração.

## Product Purpose

Hdev CRM é um CRM / plataforma de atendimento **white-label** (fork MIT do
Chatwoot 4.16, desvinculado do upstream) vendido pra agências. Sucesso =
agências operando com a própria marca, sem nenhum vestígio de Chatwoot e sem
dependência da infraestrutura do upstream.

## Positioning

White-label de verdade: a marca da agência entra por domínio customizado
(`Agency#brand_rgb` sobrescreve os tokens de acento por request), o rebrand é
total (identificadores internos inclusos) e o modelo de revenda é legítimo
porque o núcleo é MIT — o diretório `enterprise/` foi removido e **nunca volta**.

## Operating Context

- Fork sem retrocompatibilidade com Chatwoot; sem pull de updates do upstream.
- Console do Super Admin: Rails + gem administrate, views ERB sobrescritas,
  Tailwind via Vite (`superadmin` entrypoint) + SCSS do administrate.
- Dashboard principal: Vue 3 + Tailwind, design system "next" (tokens
  `--slate-*`, `--blue-*` etc. em CSS vars, claro/escuro por classe `.dark`).
- WhatsApp não-oficial via microserviço Baileys (Node), fora deste escopo.

## Capabilities and Constraints

- Idioma da UI: **pt_BR** (locale `:pt_BR`; o gem administrate só embarca
  "pt-BR" com hífen, então as chaves vivem em
  `hdevCRM/config/locales/administrate.pt_BR.yml`).
- Tema claro **e** escuro obrigatórios em toda superfície nova.
- Zeitwerk exige arquivo↔constante casados; renomeios com cuidado.
- Nunca comitar `.env`/chaves; nunca alterar `LICENSE`.
- Estrutura de planos de revenda: **em definição** (fato aberto).

## Brand Commitments

- Nome: **Hdev CRM** (instalação "Hdev CRM 1.0.0"). Suporte: contato@hdev.online.
- Logo: chevrons verdes (`hdevCRM/public/brand-assets/logo*.svg`).
- Verde da marca `#00D488` (acentos sem texto); sólido de CTA `#00875A`.
- **Proibido** os azuis do Chatwoot (`#2781F6`, `#1F93FF`) — denunciam o fork.
- Fonte: Inter (títulos e corpo).
- Referência visual completa: `identidade/design-guide.md` e `DESIGN.md`.

## Evidence on Hand

- Design system implementado: `hdevCRM/app/javascript/dashboard/assets/scss/_next-colors.scss`,
  `hdevCRM/theme/colors.js`, `hdevCRM/tailwind.config.js`.
- Guia de marca mantido pelo Harvey: `identidade/design-guide.md`.
- Não existem depoimentos/cases publicáveis ainda — não inventar.

## Product Principles

1. **White-label primeiro**: toda cor de acento nova usa os tokens
   sobrescrevíveis (`n-blue-9/10/11`), nunca hex fixo da marca.
2. **Sem rastro de Chatwoot**: nem string, nem identificador, nem azul.
3. **Operável por um dev solo**: soluções simples, superfícies consistentes,
   nada que crie manutenção desnecessária.
4. **pt-BR nativo**: a UI fala português do Brasil por padrão.
5. **Claro/escuro sempre**: nenhuma tela nova sai sem os dois temas.
