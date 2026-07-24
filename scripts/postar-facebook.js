#!/usr/bin/env node
/**
 * Publica um carrossel de fotos (ou foto única) na Página do Facebook via Meta Graph API.
 *
 * Uso:
 *   node --env-file=.env scripts/postar-facebook.js marketing/conteudo/<slug>-<data> [--slug <slug>]
 *
 * Espera na pasta do conteúdo:
 *   instagram/slide-01.png ... slide-NN.png  (mesmos PNGs do Instagram)
 *   legenda.md                               (texto do post)
 *
 * As imagens precisam estar públicas no site: <SITE_URL>/img/posts/<slug>/slide-NN.png
 *
 * .env: META_PAGE_ACCESS_TOKEN, META_PAGE_ID, SITE_URL
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

async function main() {
  const args = process.argv.slice(2);
  const folder = args.find((a) => !a.startsWith("--"));
  if (!folder) fail("Uso: node scripts/postar-facebook.js <pasta-do-conteudo> [--slug <slug>]");

  const token = requireEnv("META_PAGE_ACCESS_TOKEN");
  const pageId = requireEnv("META_PAGE_ID");
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
  if (slides.length < 1) fail(`Nenhum slide-NN.png em ${imgDir}`);

  const legendaPath = path.join(folder, "legenda.md");
  if (!fs.existsSync(legendaPath)) fail(`Legenda não encontrada: ${legendaPath}`);
  const message = fs.readFileSync(legendaPath, "utf8").trim();

  const urls = slides.map((f) => `${siteUrl}/img/posts/${slug}/${f}`);

  console.log(`→ ${slides.length} foto(s), slug "${slug}"`);
  for (const url of urls) {
    const res = await fetch(url, { method: "HEAD" });
    if (!res.ok) fail(`Imagem não acessível (${res.status}): ${url}\n  O deploy do site já terminou?`);
  }
  console.log("→ Todas as imagens estão públicas");

  // Sobe cada foto sem publicar, depois anexa todas num post único
  const mediaIds = [];
  for (const url of urls) {
    const photo = await graph(`${pageId}/photos`, {
      url,
      published: false,
      access_token: token,
    });
    mediaIds.push(photo.id);
    console.log(`→ Foto enviada: ${url.split("/").pop()}`);
  }

  const params = { message, access_token: token };
  mediaIds.forEach((id, i) => {
    params[`attached_media[${i}]`] = JSON.stringify({ media_fbid: id });
  });

  const post = await graph(`${pageId}/feed`, params);

  console.log(`✓ Publicado no Facebook: https://facebook.com/${post.id}`);
  console.log(post.id);
}

main().catch((e) => fail(e.message));
