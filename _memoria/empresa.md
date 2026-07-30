# Empresa

> Memória central do negócio. O Claude lê esse arquivo antes de cada resposta.
> Preenchido pelo `/instalar` — você pode editar a qualquer momento.

**Nome:** Harvey (marca pessoal) — produto: **HDEV CRM**
**Negócio:** SaaS white-label de CRM / atendimento
**O que faz:** CRM white-label vendido pra agências, que revendem pros clientes delas (modelo white-label / revenda)
**Perfil:** Solopreneur / dev solo
**Atende clientes:** Agências (o comprador é a agência; o usuário final é o cliente da agência)
**Equipe:** Toca sozinho
**Ferramentas:** node 24 ✓, git 2.55 ✓ (repo `solutionshdev-sudo/hdev-crm` no GitHub, branch main), gh ✓ (autenticado — é como se acompanha o CI), pnpm 10.2 ✓ (via corepack), playwright não checado. Ruby e Docker ✗ — o GitHub Actions faz o papel de interpretador Ruby
**Infra:** EasyPanel (VPS 8 GB) — instância no ar em `hdev-crm-app-crm.jz4bvz.easypanel.host` desde 26/07/2026; domínio próprio `crm.hdev.online` no ar desde 28/07/2026, **atrás do Cloudflare** (o host do EasyPanel continua respondendo direto, sem CDN — serve de origem pra comparar quando desconfiar de cache). Segundo serviço no compose: `baileys-service` (Node, WhatsApp não-oficial, rede interna, env `BAILEYS_API_KEY`)
**Principais entregas:** A plataforma HDEV CRM (fork do Chatwoot em `hdevCRM/`) e os planos de revenda pras agências. Diferenciais em produção desde 27/07: WhatsApp não-oficial via QR (Baileys 7, proxy por instância) **funcionando ponta a ponta** (recebe/envia, validado com chip real), construtor visual de chatbot e kanban de Negócios (card automático chega na rodada 2 — regra de fábrica planejada)

## Contexto adicional

- O sistema `hdevCRM/` é um **fork do Chatwoot** sendo desvinculado por completo — inclusive identificadores internos. Status e decisões em `_memoria/de-chatwoot.md`.
- O núcleo do Chatwoot é MIT (pode ser vendido); o diretório `enterprise/` tinha licença que proíbe revenda e **foi deletado em 29/07** — não é mais só "modo Community", o código não está mais no repo. Feature enterprise que fizer falta se reconstrói do zero sobre o contrato MIT que ficou no core, nunca ressuscitando aquele código do histórico do git.
- Modelo de negócio inicial: white-label pra agências. Estrutura de planos ainda em definição.
- Existe no fork um modelo `Agency` (feature própria, não do Chatwoot) que já aplica marca e cor por agência via domínio customizado.
- **IA própria (deployada em 28/07, ainda não validada em uso):** substituta MIT do Captain em `app/services/ai/` — agente de atendimento, tool calling e geração de fluxo de chatbot por linguagem natural, com quota de tokens por conta e por agência (base do rateio nos planos de revenda). O copiloto admin já aparece em Configurações → Copiloto (só pra administrador). Falta o teste ponta a ponta, que é o único ponto que valida o id do modelo `claude-opus-5` — os specs stubam o `Ai::AnthropicService` inteiro. Detalhes na terceira trilha do `_memoria/estrategia.md`.
