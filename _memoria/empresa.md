# Empresa

> Memória central do negócio. O Claude lê esse arquivo antes de cada resposta.
> Preenchido pelo `/instalar` — você pode editar a qualquer momento.

**Nome:** Harvey (marca pessoal) — produto: **HDEV CRM**
**Negócio:** SaaS white-label de CRM / atendimento
**O que faz:** CRM white-label vendido pra agências, que revendem pros clientes delas (modelo white-label / revenda)
**Perfil:** Solopreneur / dev solo
**Atende clientes:** Agências (o comprador é a agência; o usuário final é o cliente da agência)
**Equipe:** Toca sozinho
**Ferramentas:** node 24 ✓, git 2.55 ✓ (repo `solutionshdev-sudo/hdev-crm` no GitHub, branch main), gh ✗ (opcional), playwright não checado
**Infra:** EasyPanel (VPS 8 GB) — instância no ar em `hdev-crm-app-crm.jz4bvz.easypanel.host` desde 26/07/2026; domínio próprio `crm.hdev.online` ainda pendente de DNS
**Principais entregas:** A plataforma HDEV CRM (fork do Chatwoot em `hdevCRM/`) e os planos de revenda pras agências

## Contexto adicional

- O sistema `hdevCRM/` é um **fork do Chatwoot** sendo desvinculado por completo — inclusive identificadores internos. Status e decisões em `_memoria/de-chatwoot.md`.
- O núcleo do Chatwoot é MIT (pode ser vendido); o diretório `enterprise/` tem licença que proíbe revenda — por isso o produto roda em modo Community, e as features enterprise que importarem serão reconstruídas com código próprio.
- Modelo de negócio inicial: white-label pra agências. Estrutura de planos ainda em definição.
- Existe no fork um modelo `Agency` (feature própria, não do Chatwoot) que já aplica marca e cor por agência via domínio customizado.
