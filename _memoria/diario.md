# Diário de sessões

> Continuidade entre sessões. O `/salvar` registra aqui uma linha do que
> foi feito; o `/abrir` lê as últimas entradas pra retomar de onde parou.
> Formato: `- AAAA-MM-DD — o que foi feito (1 linha)`. Mais recente no topo.

- 2026-07-26 — Instância no ar no EasyPanel (o container web estava parado; rota do domínio apontada pra web:3000). Auditoria completa achou o job enterprise que revertia o rebrand todo dia + telemetria pro hub do Chatwoot; apurada a licença (core MIT vendável, `enterprise/` proíbe revenda) e decidido ir pra modo Community. Plano de 6 fases aprovado. Executado: paleta verde + 30 favicons + /swagger fechado (commit 5d1208e), kill-switch DISABLE_ENTERPRISE e marca restaurada no banco. Pendente: erro 500 no /super_admin
- 2026-07-23 — /instalar (perfil solopreneur/dev, HDEV CRM white-label pra agências); rebrand Chatwoot→Hdev CRM no fork (2.340 strings de UI/e-mails, views, config, e-mails de suporte sac@/contato@hdev.online); git instalado + repo iniciado (4 commits); artefatos de deploy EasyPanel prontos (docker-compose.easypanel.yaml + INSTALAR-EASYPANEL.md)
- 2026-07-20 — Template HDEV v1.2.0 finalizado e publicado no GitHub (regras em _sistema/, trava de segredos, scripts prontos, /atualizar-sistema)
