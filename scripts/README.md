# scripts/ — utilitários do HDEV

Scripts Node.js que as skills chamam quando precisam fazer coisas fora do alcance da IA pura (gerar imagem, postar em rede social, renderizar HTML em PNG).

Os scripts de integração **já vêm prontos no template** — mesma versão testada em todos os projetos. Você só precisa preencher o `.env` (copie de `.env.example`) quando for ativar cada integração.

## Scripts incluídos

| Skill | Script | O que faz |
|---|---|---|
| `/carrossel` (com foto IA) | `gerar-imagem.js` | Gera foto realista via OpenAI API (modelo `gpt-image-1`) |
| `/carrossel` (render PNG) | `render-carrossel.js` | Playwright tira screenshot de cada `.slide` do carrossel.html (1080x1350 ou 9:16) |
| `/aprovar-post` | `verificar-integracoes.js` | Testa token Meta (com data de expiração), Página, Instagram, OpenAI e site |
| `/aprovar-post` | `postar-instagram.js` | Publica carrossel no Instagram via Meta Graph API |
| `/aprovar-post` | `postar-facebook.js` | Publica carrossel no Facebook via Meta Graph API |
| `/anuncio-google` | (nenhum — gera CSV direto) | — |
| `/relatorio-ads` | (CSV exportado, ou MCP do Meta Ads se conectado) | — |

Uso rápido:

```bash
node --env-file=.env scripts/verificar-integracoes.js            # ou: npm run verificar
node --env-file=.env scripts/gerar-imagem.js "PROMPT" "saida.png"
node scripts/render-carrossel.js marketing/conteudo/<pasta>
node --env-file=.env scripts/postar-instagram.js marketing/conteudo/<pasta>
node --env-file=.env scripts/postar-facebook.js marketing/conteudo/<pasta>
```

**Dica:** o token de Página da Meta vence a cada ~60 dias. Rode `npm run verificar` de vez em quando — ele avisa quantos dias faltam.

## Pré-requisitos comuns

A maioria dos scripts depende de:

**Node.js 20+** instalado na máquina

**.env** na raiz do projeto com as chaves de API:
```bash
OPENAI_API_KEY=sk-...               # pra gerar-imagem.js
META_PAGE_ACCESS_TOKEN=...          # pra postar-instagram.js + postar-facebook.js
META_PAGE_ID=...
META_IG_USER_ID=...
SITE_URL=https://seudominio.com.br
```

**Playwright** (pra renderizar HTML em PNG):
```bash
npm install playwright
npx playwright install chromium
```

## Como o HDEV lida com isso

Quando você roda uma skill que precisa de integração ainda não configurada, o Claude vai:

1. Detectar que falta chave no `.env` (ou dependência como Playwright)
2. Te perguntar se quer configurar agora
3. Te guiar no setup das chaves de API (Meta, OpenAI, etc.)
4. Rodar a skill

Você não precisa decorar nada. Roda a skill, segue o fluxo. Os scripts não devem ser reescritos por projeto — melhorias neles entram no template e chegam via `/atualizar-sistema`.
