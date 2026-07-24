#!/usr/bin/env node
/**
 * Verifica se as integrações configuradas no .env estão vivas ANTES de precisar delas.
 * Testa: token da Meta (validade e expiração), Página FB, conta Instagram, chave OpenAI e site.
 *
 * Uso:
 *   node --env-file=.env scripts/verificar-integracoes.js
 *
 * Só testa o que estiver preenchido no .env — variável vazia é reportada como "não configurada".
 * Sai com código 1 se alguma integração configurada estiver quebrada (bom pra usar em pipelines).
 */

const GRAPH = "https://graph.facebook.com/v21.0";

let problemas = 0;

function ok(msg) {
  console.log(`✓ ${msg}`);
}
function warn(msg) {
  console.log(`— ${msg}`);
}
function bad(msg) {
  problemas++;
  console.log(`✗ ${msg}`);
}

async function checkMeta() {
  const token = process.env.META_PAGE_ACCESS_TOKEN;
  if (!token) return warn("Meta: não configurada (META_PAGE_ACCESS_TOKEN vazio)");

  // Valida o token e lê a expiração
  const dbg = await fetch(
    `${GRAPH}/debug_token?input_token=${encodeURIComponent(token)}&access_token=${encodeURIComponent(token)}`
  ).then((r) => r.json());

  if (dbg.error || !dbg.data?.is_valid) {
    return bad(`Meta: token inválido ou vencido (${dbg.error?.message || "is_valid=false"}) — gere um novo token de longa duração`);
  }

  const exp = dbg.data.expires_at;
  if (exp === 0) {
    ok("Meta: token válido, sem data de expiração");
  } else {
    const dias = Math.floor((exp * 1000 - Date.now()) / 86400000);
    if (dias <= 7) bad(`Meta: token vence em ${dias} dia(s) — renove AGORA`);
    else if (dias <= 15) console.log(`⚠ Meta: token vence em ${dias} dias — renovar em breve`);
    else ok(`Meta: token válido (vence em ${dias} dias)`);
  }

  const pageId = process.env.META_PAGE_ID;
  if (pageId) {
    const page = await fetch(
      `${GRAPH}/${pageId}?fields=name&access_token=${encodeURIComponent(token)}`
    ).then((r) => r.json());
    if (page.error) bad(`Meta: Página ${pageId} inacessível (${page.error.message})`);
    else ok(`Meta: Página "${page.name}" acessível`);
  } else warn("Meta: META_PAGE_ID vazio");

  const igId = process.env.META_IG_USER_ID;
  if (igId) {
    const ig = await fetch(
      `${GRAPH}/${igId}?fields=username&access_token=${encodeURIComponent(token)}`
    ).then((r) => r.json());
    if (ig.error) bad(`Meta: conta Instagram ${igId} inacessível (${ig.error.message})`);
    else ok(`Meta: Instagram @${ig.username} acessível`);
  } else warn("Meta: META_IG_USER_ID vazio");
}

async function checkOpenAI() {
  const key = process.env.OPENAI_API_KEY;
  if (!key) return warn("OpenAI: não configurada (OPENAI_API_KEY vazio)");
  const res = await fetch("https://api.openai.com/v1/models", {
    headers: { Authorization: `Bearer ${key}` },
  });
  if (res.ok) ok("OpenAI: chave válida");
  else bad(`OpenAI: chave rejeitada (HTTP ${res.status})`);
}

async function checkSite() {
  const url = process.env.SITE_URL;
  if (!url) return warn("Site: não configurado (SITE_URL vazio)");
  try {
    const res = await fetch(url.replace(/\/$/, ""), { method: "HEAD", redirect: "follow" });
    if (res.ok) ok(`Site: ${url} no ar (HTTP ${res.status})`);
    else bad(`Site: ${url} respondeu HTTP ${res.status}`);
  } catch (e) {
    bad(`Site: ${url} inacessível (${e.message})`);
  }
}

async function main() {
  console.log("Verificando integrações...\n");
  await checkMeta();
  await checkOpenAI();
  await checkSite();
  console.log(
    problemas === 0
      ? "\n✓ Tudo certo com o que está configurado."
      : `\n✗ ${problemas} problema(s) encontrado(s) — resolver antes de publicar.`
  );
  process.exit(problemas === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(`✗ Falha inesperada: ${e.message}`);
  process.exit(1);
});
