#!/usr/bin/env node
/**
 * Gera uma imagem realista via OpenAI (modelo gpt-image-1) e salva em PNG.
 *
 * Uso:
 *   node --env-file=.env scripts/gerar-imagem.js "PROMPT" "caminho/saida.png" [--size 1024x1536]
 *
 * Tamanhos aceitos: 1024x1024, 1536x1024 (paisagem), 1024x1536 (retrato).
 * Padrão: 1024x1536 — proporção próxima do slide 1080x1350 do Instagram.
 *
 * .env: OPENAI_API_KEY
 */

const fs = require("node:fs");
const path = require("node:path");

function fail(msg) {
  console.error(`✗ ${msg}`);
  process.exit(1);
}

async function main() {
  const args = process.argv.slice(2);
  const [prompt, outPath] = args.filter((a) => !a.startsWith("--"));
  if (!prompt || !outPath)
    fail('Uso: node scripts/gerar-imagem.js "PROMPT" "saida.png" [--size 1024x1536]');

  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) fail("Variável OPENAI_API_KEY ausente no .env");

  const sizeFlag = args.indexOf("--size");
  const size = sizeFlag !== -1 ? args[sizeFlag + 1] : "1024x1536";
  const valid = ["1024x1024", "1536x1024", "1024x1536"];
  if (!valid.includes(size)) fail(`--size deve ser um de: ${valid.join(", ")}`);

  console.log(`→ Gerando imagem ${size} (gpt-image-1)...`);

  const res = await fetch("https://api.openai.com/v1/images/generations", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-image-1",
      prompt,
      size,
      n: 1,
    }),
  });

  const json = await res.json();
  if (!res.ok) fail(`OpenAI API: ${json.error?.message || res.statusText}`);

  const b64 = json.data?.[0]?.b64_json;
  if (!b64) fail("Resposta sem imagem (b64_json vazio)");

  fs.mkdirSync(path.dirname(path.resolve(outPath)), { recursive: true });
  fs.writeFileSync(outPath, Buffer.from(b64, "base64"));

  console.log(`✓ Imagem salva: ${outPath}`);
}

main().catch((e) => fail(e.message));
