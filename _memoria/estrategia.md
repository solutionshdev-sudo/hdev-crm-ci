# Estratégia

> O que importa agora. Prioridades, metas, prazos.
> O Claude usa isso pra decidir o que sugerir primeiro e o que adiar.
> Atualize sempre que as prioridades mudarem.

## Fase

Construção do produto — white-label do fork do Chatwoot pra virar HDEV CRM.

## Prioridade principal

Rebrand Chatwoot → Hdev CRM (grafia oficial: "Hdev CRM"). Trocar só a marca
visível ao usuário, sem quebrar identificadores internos (classes
`ChatwootApp`/`ChatwootHub`, pacotes npm `@chatwoot/*`, variáveis
`latestChatwootVersion`/`isOnChatwootCloud`, tabelas, feature flags, serviços
de deploy).

**Progresso (rebrand — feito nesta sessão, 3 commits em `main`):**
- ✓ i18n frontend (todos os idiomas): 2.067 strings
- ✓ i18n backend/locales YAML: 273 strings
- ✓ Views e e-mails do backend: títulos, onboarding, e-mails de exclusão, "Powered by"
- ✓ `installation_config.yml`: TERMS_URL/PRIVACY_URL neutralizadas
- ✓ E-mails de suporte: `sac@hdev.online` (cliente) e `contato@hdev.online` (admin)
- ✓ Logos, manifest.json e INSTALLATION_NAME já eram "Hdev CRM"

**Falta no rebrand:**
- URLs de documentação em `constants/globals.js` ainda apontam pra chatwoot.com/docs
- Setar `MAILER_SUPPORT_EMAIL` = `sac@hdev.online` no painel Super Admin
- Teste real: subir a instância Rails+Vue e conferir dashboard/e-mails na tela

## O que pode esperar

- Definição da estrutura de planos de revenda pras agências (ainda em estudo).
- Skills de marketing/conteúdo do template (carrossel, SEO, ads) — o foco
  agora é produto, não divulgação.

## Contexto com prazo

- Git instalado (v2.55) e repo inicializado (branch `main`, 3 commits locais).
  Falta conectar ao GitHub remoto pra dar push — rodar `/salvar` quando quiser.
