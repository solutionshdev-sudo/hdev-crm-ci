# Estratégia

> O que importa agora. Prioridades, metas, prazos.
> O Claude usa isso pra decidir o que sugerir primeiro e o que adiar.
> Atualize sempre que as prioridades mudarem.

## Fase

Produto no ar (EasyPanel, 26/07/2026) — em processo de desvinculação total do
Chatwoot antes de abrir pra agências.

## Prioridade principal

**Desvincular o Hdev CRM do Chatwoot.** Status detalhado, decisões e armadilhas
em `_memoria/de-chatwoot.md` — ler antes de mexer no código.

Resumo: sair do modo enterprise (licença proíbe revenda), cortar telemetria,
remover toda menção ao Chatwoot (inclusive identificadores internos e a
superfície JS do widget) e completar a identidade visual verde.

**Feito (26/07):** paleta verde completa + favicons regerados + `/swagger`
fechado (commit `5d1208e`); kill-switch `DISABLE_ENTERPRISE` ativo em produção;
valores de marca restaurados no banco.

**Bloqueador agora:** `/super_admin` retornando erro 500 — diagnosticar pelo log
antes de qualquer outra coisa.

**Próximo:** remover a pasta `enterprise/` de vez, depois textos/links visíveis,
depois o rename do widget e dos identificadores internos.

## O que pode esperar

- Definição da estrutura de planos de revenda pras agências (ainda em estudo).
- Reconstrução das features enterprise com código próprio (SLA, audit logs,
  custom roles, companies) — só depois da desvinculação terminar.
- Skills de marketing/conteúdo do template (carrossel, SEO, ads) — o foco
  agora é produto, não divulgação.

## Contexto com prazo

- Domínio `crm.hdev.online` sem DNS. Como `FRONTEND_URL` já aponta pra ele,
  links de e-mail saem quebrados até criar o registro A no Cloudflare.
- SMTP não configurado: convites de agente e recuperação de senha não saem.
- Backup do Postgres feito manualmente uma vez; falta a rotina de cron.
