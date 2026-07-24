#!/usr/bin/env node
/**
 * Renderiza os slides de um carrossel.html em PNGs via Playwright.
 *
 * Uso:
 *   node scripts/render-carrossel.js marketing/conteudo/<pasta> [--out instagram] [--size 1080x1350]
 *
 * Espera <pasta>/carrossel.html com cada slide num elemento `.slide`.
 * Gera <pasta>/<out>/slide-01.png ... slide-NN.png (padrão: instagram/, 1080x1350).
 * Pra Reels/TikTok: --out tiktok --size 1080x1920 (o HTML precisa estar nesse formato).
 *
 * Requer Playwright instalado na raiz do projeto:
 *   npm install playwright && npx playwright install chromium
 */

const fs = require("node:fs");
const path = require("node:path");

function fail(msg) {
  console.error(`✗ ${msg}`);
  process.exit(1);
}

async function main() {
  const args = process.argv.slice(2);
  const folder = args.find((a) => !a.startsWith("--"));
  if (!folder) fail("Uso: node scripts/render-carrossel.js <pasta> [--out instagram] [--size 1080x1350]");

  const outFlag = args.indexOf("--out");
  const outDirName = outFlag !== -1 ? args[outFlag + 1] : "instagram";
  const sizeFlag = args.indexOf("--size");
  const size = sizeFlag !== -1 ? args[sizeFlag + 1] : "1080x1350";
  const [width, height] = size.split("x").map(Number);
  if (!width || !height) fail(`--size inválido: ${size} (esperado LARGURAxALTURA, ex: 1080x1350)`);

  const htmlPath = path.resolve(folder, "carrossel.html");
  if (!fs.existsSync(htmlPath)) fail(`Não achei ${htmlPath}`);

  let chromium;
  try {
    ({ chromium } = require("playwright"));
  } catch {
    fail("Playwright não instalado. Rode: npm install playwright && npx playwright install chromium");
  }

  const outDir = path.resolve(folder, outDirName);
  fs.mkdirSync(outDir, { recursive: true });

  const browser = await chromium.launch();
  const page = await browser.newPage({
    viewport: { width, height },
    deviceScaleFactor: 1,
  });

  await page.goto(`file://${htmlPath}`);
  // Aguarda fontes (Google Fonts) e imagens carregarem
  await page.waitForLoadState("networkidle");
  await page.evaluate(() => document.fonts.ready);

  const slides = page.locator(".slide");
  const count = await slides.count();
  if (count === 0) fail("Nenhum elemento .slide encontrado no carrossel.html");

  for (let i = 0; i < count; i++) {
    const file = path.join(outDir, `slide-${String(i + 1).padStart(2, "0")}.png`);
    await slides.nth(i).screenshot({ path: file });
    console.log(`→ ${path.relative(process.cwd(), file)}`);
  }

  await browser.close();
  console.log(`✓ ${count} slide(s) renderizado(s) em ${width}x${height}`);
}

main().catch((e) => fail(e.message));
