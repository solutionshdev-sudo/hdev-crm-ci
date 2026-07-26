# Projeto: desvincular o Hdev CRM do Chatwoot

> Documento de trabalho da migração. Atualizar ao fim de cada fase.
> Última atualização: **2026-07-26**

---

## Por que esse projeto existe

O Hdev CRM é um fork do Chatwoot 4.16.0 vendido como white-label para agências.
Três problemas impediam isso de funcionar:

1. **Um job diário desfazia o rebrand.** A extensão enterprise do
   `CheckNewVersionsJob` chama `ReconcilePlanConfigService`, que ao detectar plano
   "community" reescrevia no banco `INSTALLATION_NAME` → "Chatwoot", logos,
   `BRAND_URL`/`TERMS_URL`/`PRIVACY_URL` → chatwoot.com, `DISPLAY_MANIFEST` → true,
   e desabilitava `disable_branding` em todas as contas. Era a origem do banner
   "An update 4.16.1 is available" que aparecia no dashboard.
2. **A instância conversava com a infraestrutura do Chatwoot**: ping diário com
   contagem de contas/usuários/conversas, relay de push mobile, widget de suporte
   no Super Admin, e `/swagger` público anunciando "Chatwoot".
3. **A marca estava pela metade**: logos verdes, UI azul, favicons do Chatwoot.

## A questão de licença (define tudo)

- **`hdevCRM/LICENSE`** — o núcleo é **MIT**. Pode modificar, sublicenciar e
  **vender**. Rebrandar e revender para agências é legítimo; basta manter o aviso
  de copyright (nunca alterar o arquivo `LICENSE`).
- **`hdevCRM/enterprise/LICENSE`** — o conteúdo dessa pasta *"may only be used in
  production [with] a valid Chatwoot Enterprise License"* e *"it is forbidden to
  copy, merge, publish, distribute, sublicense, and/or sell the Software"*.
  Ou seja: **usar em produção sem assinatura, e revender, viola a licença.**
- **O app entra em modo enterprise só pela presença da pasta `enterprise/`**
  (`lib/chatwoot_app.rb:14-18`). Não há chave de licença nem verificação
  criptográfica — o "plano" é uma string em `installation_configs`.
  Remover a pasta resolve a exposição jurídica **e** mata o job de reversão.

**Decisão tomada:** sair do modo enterprise, e reconstruir depois com código
próprio (MIT, vendável) as features que importarem — prioridade: **SLA**,
**audit logs**, **custom roles**, **companies** (as tabelas continuam existindo,
pois as migrations são do core MIT).

**Ganho já obtido:** `disable_branding` — que remove o "Powered by" do widget,
portal e rodapé de e-mail — é implementado no core MIT. Só o serviço enterprise
o desligava diariamente. Agora pode ser ligado por conta e permanece.

## Outras decisões aprovadas

| Tema | Decisão |
|---|---|
| Profundidade do rename | **Tudo**, inclusive identificadores internos Ruby e a superfície JS do widget, **sem retrocompatibilidade** (não há widget instalado em cliente ainda) |
| Updates do upstream | **Não** vamos puxar. O fork segue vida própria — libera renames agressivos, mas a manutenção de segurança passa a ser nossa |
| Cor de acento | Verde `#00D488` do logo. Sólido de CTA: `#00875A` |

---

## Onde paramos (2026-07-26)

### ✅ Concluído

**Fase 1 (código) e Fase 4 completas** — commit `5d1208e`, já em `main` no GitHub:
- `/swagger` deixou de ser servido em produção (era público, sem autenticação)
- Paleta verde aplicada: tokens `--blue-1..12` claro/escuro, `brand` do Tailwind,
  paleta legada `woot-*`, e-mails, `manifest.json`, flash do launcher do widget,
  administrate, e todos os hex azuis remanescentes
- 30 favicons/ícones PWA regerados (tile `#0F172A` + chevrons `#00FF9F`)
- Migration `20260726120000` — default de `widget_color` → `#00875A` + backfill
- `identidade/design-guide.md` preenchido com a paleta oficial

**Fase 1 (servidor) e Fase 2 executadas pelo Harvey no EasyPanel:**
- Env vars `DISABLE_ENTERPRISE=true`, `ENABLE_PUSH_RELAY_SERVER=false`,
  `DISABLE_TELEMETRY=true` adicionadas e implantadas
- Os 10 valores de marca restaurados no banco (saída confirmou `OK` para todos)
- Chave Redis do alerta (`CHATWOOT_CONFIG_RESET_WARNING`) limpa

### 🔴 Bloqueador aberto — Super Admin dando erro 500

Depois de rodar os comandos da Fase 2, o **`/super_admin` retorna 500 e não abre**.
Ainda não diagnosticado. Hipóteses a testar, em ordem:

1. As views de Super Admin leem `ChatwootApp.enterprise?` e `ChatwootHub.pricing_plan`
   em vários pontos (`settings/show.html.erb`, `_upgrade_button_enterprise.html.erb`,
   `app/helpers/super_admin/features.yml` com ERB `<%= ChatwootApp.enterprise? %>`).
   Com `DISABLE_ENTERPRISE`, `enterprise?` passa a retornar **`nil`** (não `false`) —
   um `nil` interpolado num YAML de features pode gerar valor inválido.
2. `DISPLAY_MANIFEST` voltou para `false` e alguma view do Super Admin pode depender dele.
3. Algum `InstallationConfig` que a tela espera existir ficou com valor inesperado.

**Como diagnosticar (primeira coisa da próxima sessão):**
```
docker logs <container_web> --since 15m | grep -B5 -A40 "Completed 500\|Error\|Exception"
```
ou, dentro do container: `tail -200 /app/log/production.log`.

O stack trace vai apontar a linha exata. **Não mexer em nada antes de ver o trace** —
o resto da aplicação (dashboard, conversas, widget) precisa ser verificado também
para saber se o 500 é só do Super Admin ou geral.

### ⏳ Próximas fases (planejadas, não iniciadas)

| Fase | O que é | Pré-requisito |
|---|---|---|
| **3** | Remover `enterprise/` e `spec/enterprise/` de vez; deletar `lib/chatwoot_hub.rb` e toda a telemetria; remover `UpdateBanner`, changelog card, testimonials | 48h estável com `DISABLE_ENTERPRISE` + o 500 resolvido |
| **3b** | Textos e links visíveis: URLs `chatwoot.com` em `globals.js`, termos/privacidade no signup (~50 locales), `helpCenter.json`, e-mails (`accounts@chatwoot.com`), locales `ja`/`ko`/`sl` | precisa de páginas próprias de Termos e Privacidade publicadas |
| **5** | Superfície do widget: `window.chatwootSDK`→`hdevSDK`, `$chatwoot`→`$hdev`, classes `woot-*`→`hdev-*` (617 refs), cookies `cw_`→`hd_`, eventos, postMessage, headers `X-Chatwoot-*` | Fases 3 e 4 |
| **6** | Identificadores internos Ruby (~357 refs), `db:chatwoot_prepare`, feature flags, chaves `CHATWOOT_*` | Fases 1-5 estáveis |

Plano detalhado com comandos, armadilhas e verificação por fase:
`C:\Users\hdev\.claude\plans\crie-um-plano-completo-buzzing-stardust.md`

---

## Armadilhas que já custaram tempo (não repetir)

- **`ENV.fetch('DISABLE_ENTERPRISE', false)` retorna string** — `"false"` também é
  verdadeiro em Ruby. Qualquer valor liga o kill-switch.
- **Nunca rodar `ConfigLoader.new.process(reconcile_only_new: false)`** — reescreve
  ~150 chaves e apaga credenciais (SMTP, integrações) configuradas pela UI.
- **Nunca rodar `db:seed` em produção** — cria a conta de exemplo "Acme Inc".
- **Nunca reordenar `config/features.yml`** — as flags são um bitset por posição;
  reordenar embaralha as features de todas as contas. Renomear o `name` é seguro.
- **`db:chatwoot_prepare` é chamado pelo `command` do `docker-compose.easypanel.yaml`**,
  não pelo entrypoint. Renomear a task sem atualizar o compose derruba a instância.
- **Mudança de JS/SCSS só aparece após rebuild da imagem** (o Dockerfile roda
  `assets:precompile` no build) — restart não basta.
- **`INSTALLATION_NAME`/`BRAND_NAME` no bloco `environment` do compose são no-ops** —
  nenhum código lê essas chaves do ENV; os valores vêm da tabela `installation_configs`.
- **As chaves de marca nascem `locked: true`** e por isso não aparecem em
  `/super_admin/installation_configs`. Só dá para editá-las via `rails runner`.

## Pendências de infra herdadas

- **Backup do Postgres**: feito manualmente uma vez. Falta a rotina de cron diária.
- **DNS `crm.hdev.online`**: ainda não existe. A instância roda no domínio
  `hdev-crm-app-crm.jz4bvz.easypanel.host`, mas `FRONTEND_URL` aponta para
  `crm.hdev.online` — links de e-mail saem errados até isso ser resolvido.
- **SMTP**: não configurado. Convites de agente e recuperação de senha não saem.
