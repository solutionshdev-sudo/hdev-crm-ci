# Changelog do template HDEV

Registro de versões do inicializador. Projetos criados a partir do
template usam `/atualizar-sistema` pra puxar melhorias de versões novas.
O número da versão local fica no arquivo `VERSION`.

## 1.2.0 — 2026-07-20

- `scripts/render-carrossel.js` — renderizador fixo de carrossel (antes o
  `/carrossel` gerava um `render.js` diferente em cada pasta de conteúdo)
- `scripts/verificar-integracoes.js` — testa token da Meta (com dias até
  vencer), Página, Instagram, chave OpenAI e site; o `/aprovar-post` roda
  antes de publicar (`npm run verificar` também funciona)
- Correção nos scripts de postagem: Graph API agora recebe parâmetros
  form-encoded (o formato JSON com chaves `attached_media[N]` não era
  interpretado) e o Instagram falha explícito se o container não ficar
  pronto em 60s em vez de publicar às cegas
- `package.json` na raiz com Playwright como dependência (`npm install`
  resolve o render) e atalho `npm run verificar`
- Template publicado como repositório-template no GitHub

## 1.1.0 — 2026-07-19

**Correções estruturais:**
- Regras de operação movidas pra `_sistema/regras.md`, importadas via
  `@_sistema/regras.md` no `CLAUDE.md` e nos 4 moldes de perfil — antes,
  o `/instalar` sobrescrevia o `CLAUDE.md` e o sistema perdia as regras
  de auto-aprendizado
- `.gitignore` e `.env.example` incluídos no template — elimina o risco
  de comitar tokens no primeiro `/salvar`
- `/salvar` ganhou trava de segredos (bloqueia `.env*`, `*token*`,
  `*secret*`, `*.pem`, `*.key` no staging)

**Novidades:**
- `_memoria/diario.md` — continuidade entre sessões (o `/salvar` registra,
  o `/abrir` retoma)
- `tarefas.md` na raiz (os perfis já referenciavam, o arquivo não existia)
- Skill `/atualizar-sistema` — propaga melhorias do template pra projetos
  já criados sem tocar na memória do negócio
- `/instalar` agora: checa perfil global em `~/.hdev/perfil.md` (não
  repete a entrevista pessoal a cada projeto), roda diagnóstico de
  ambiente (git, node, gh, playwright) e oferece o primeiro commit
- Scripts prontos e testáveis em `scripts/`: `postar-instagram.js`,
  `postar-facebook.js`, `gerar-imagem.js` (antes eram gerados na hora,
  cada projeto ganhava uma versão diferente)
- `.claude/settings.json` com permissões seguras pré-aprovadas
- `/relatorio-ads` detecta MCP do Meta Ads conectado e puxa dados ao
  vivo em vez de exigir CSV manual
- Versionamento do template: `VERSION` + esse changelog

**Ajustes:**
- Referência de geração de imagem atualizada de DALL-E 3 pra `gpt-image-1`
- README sem número fixo de skills (quebrava a cada skill nova)

## 1.0.0

- Base original do template (MazyOS): 15 skills, memória em `_memoria/`,
  identidade em `identidade/`, templates de perfil e ciclo
  instalar → abrir → trabalhar → salvar → atualizar
