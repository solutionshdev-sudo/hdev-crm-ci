#!/usr/bin/env node
/**
 * Publica um carrossel (ou imagem única) no Instagram via Meta Graph API.
 *
 * Uso:
 *   node --env-file=.env scripts/postar-instagram.js marketing/conteudo/<slug>-<data> [--slug <slug>]
 *
 * Espera na pasta do conteúdo:
 *   instagram/slide-01.png ... slide-NN.png  (1 a 10 imagens)
 *   legenda.md                               (texto da legenda)
 *
 * As imagens precisam estar publicadas no site (a Meta busca por URL pública):
 *   <SITE_URL>/img/posts/<slug>/slide-NN.png
 *
 * .env: META_PAGE_ACCESS_TOKEN, META_IG_USER_ID, SITE_URL
 */

const fs = require("node:fs");
const path = require("node:path");

const GRAPH = "https://graph.facebook.com/v21.0";

function fail(msg) {
  console.error(`✗ ${msg}`);
  process.exit(1);
}

function requireEnv(name) {
  const v = process.env[name];
  if (!v) fail(`Variável ${name} ausente no .env`);
  return v;
}

async function graph(pathname, params) {
  const res = await fetch(`${GRAPH}/${pathname}`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(params).toString(),
  });
  const json = await res.json();
  if (!res.ok || json.error) {
    fail(`Graph API (${pathname}): ${json.error?.message || res.statusText}`);
  }
  return json;
}

async function graphGet(pathname, params) {
  const qs = new URLSearchParams(params).toString();
  const res = await fetch(`${GRAPH}/${pathname}?${qs}`);
  const json = await res.json();
  if (!res.ok || json.error) {
    fail(`Graph API GET (${pathname}): ${json.error?.message || res.statusText}`);
  }
  return json;
}

async function main() {
  const args = process.argv.slice(2);
  const folder = args.find((a) => !a.startsWith("--"));
  if (!folder) fail("Uso: node scripts/postar-instagram.js <pasta-do-conteudo> [--slug <slug>]");

  const token = requireEnv("META_PAGE_ACCESS_TOKEN");
  const igUserId = requireEnv("META_IG_USER_ID");
  const siteUrl = requireEnv("SITE_URL").replace(/\/$/, "");

  const slugFlag = args.indexOf("--slug");
  const slug =
    slugFlag !== -1
      ? args[slugFlag + 1]
      : path.basename(folder).replace(/-\d{4}-\d{2}-\d{2}$/, "");

  const imgDir = path.join(folder, "instagram");
  if (!fs.existsSync(imgDir)) fail(`Pasta não encontrada: ${imgDir}`);
  const slides = fs
    .readdirSync(imgDir)
    .filter((f) => /^slide-\d+\.png$/i.test(f))
    .sort();
  if (slides.length < 1 || slides.length > 10)
    fail(`Esperado 1 a 10 slides em ${imgDir}, achei ${slides.length}`);

  const legendaPath = path.join(folder, "legenda.md");
  if (!fs.existsSync(legendaPath)) fail(`Legenda não encontrada: ${legendaPath}`);
  const caption = fs.readFileSync(legendaPath, "utf8").trim();

  const urls = slides.map((f) => `${siteUrl}/img/posts/${slug}/${f}`);

  console.log(`→ ${slides.length} slide(s), slug "${slug}"`);
  for (const url of urls) {
    const res = await fetch(url, { method: "HEAD" });
    if (!res.ok) fail(`Imagem não acessível (${res.status}): ${url}\n  O deploy do site já terminou?`);
  }
  console.log("→ Todas as imagens estão públicas");

  let creationId;
  if (slides.length === 1) {
    const single = await graph(`${igUserId}/media`, {
      image_url: urls[0],
      caption,
      access_token: token,
    });
    creationId = single.id;
  } else {
    const children = [];
    for (const url of urls) {
      const item = await graph(`${igUserId}/media`, {
        image_url: url,
        is_carousel_item: true,
        access_token: token,
      });
      children.push(item.id);
      console.log(`→ Container criado: ${url.split("/").pop()}`);
    }
    const carousel = await graph(`${igUserId}/media`, {
      media_type: "CAROUSEL",
      children: children.join(","),
      caption,
      access_token: token,
    });
    creationId = carousel.id;
  }

  // Aguarda o container ficar pronto antes de publicar
  let ready = false;
  for (let i = 0; i < 20 && !ready; i++) {
    const st = await graphGet(creationId, {
      fields: "status_code",
      access_token: token,
    });
    if (st.status_code === "FINISHED") ready = true;
    else if (st.status_code === "ERROR") fail("Container retornou status ERROR");
    else await new Promise((r) => setTimeout(r, 3000));
  }
  if (!ready) fail("Container não ficou pronto em 60s — tente de novo em instantes");

  const pub = await graph(`${igUserId}/media_publish`, {
    creation_id: creationId,
    access_token: token,
  });

  const info = await graphGet(pub.id, {
    fields: "permalink",
    access_token: token,
  });

  console.log(`✓ Publicado no Instagram: ${info.permalink || pub.id}`);
  console.log(pub.id);
}

main().catch((e) => fail(e.message));
