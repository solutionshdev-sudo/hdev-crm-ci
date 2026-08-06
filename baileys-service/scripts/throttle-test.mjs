// Prova §2.6.1 do plano Motor Integrado: o sendChain do baileys-service
// serializa envios com >=1s + jitter (SEND_DELAY_MS em instance.ts).
// Dispara N POSTs /messages de uma vez e mede o espaçamento das conclusões
// (a resposta só volta depois do envio real, então o delta entre respostas
// é o delta entre envios).
//
// Uso (instância já pareada e status connected):
//   BAILEYS_API_KEY=... INSTANCE_ID=... TO=5599999999999 node scripts/throttle-test.mjs
// Opcionais: BAILEYS_URL (default http://localhost:3025), N (default 5)

const url = process.env.BAILEYS_URL || 'http://localhost:3025';
const apiKey = process.env.BAILEYS_API_KEY;
const instanceId = process.env.INSTANCE_ID;
const to = process.env.TO;
const n = Number(process.env.N || 5);

if (!apiKey || !instanceId || !to) {
  console.error('Faltou env: BAILEYS_API_KEY, INSTANCE_ID e TO são obrigatórios.');
  process.exit(2);
}

const status = await fetch(`${url}/instances/${instanceId}`, {
  headers: { authorization: `Bearer ${apiKey}` },
}).then(r => r.json());
if (status.status !== 'connected') {
  console.error(`Instância '${instanceId}' não está connected (status: ${status.status}). Pareia primeiro.`);
  process.exit(2);
}

console.log(`Disparando ${n} POSTs /messages de uma vez pra ${to}...`);
const t0 = performance.now();
const results = await Promise.all(
  Array.from({ length: n }, (_, i) =>
    fetch(`${url}/instances/${instanceId}/messages`, {
      method: 'POST',
      headers: { authorization: `Bearer ${apiKey}`, 'content-type': 'application/json' },
      body: JSON.stringify({ to, type: 'text', text: { body: `throttle-test ${i + 1}/${n}` } }),
    }).then(async r => ({ i: i + 1, ok: r.ok, doneAt: performance.now() - t0, body: await r.json() }))
  )
);

const byCompletion = [...results].sort((a, b) => a.doneAt - b.doneAt);
let previous = 0;
let minDelta = Infinity;
for (const r of byCompletion) {
  const delta = r.doneAt - previous;
  if (previous > 0) minDelta = Math.min(minDelta, delta);
  console.log(
    `msg ${r.i}: ${r.ok ? 'ok' : 'FALHOU'} em ${(r.doneAt / 1000).toFixed(2)}s` +
      (previous > 0 ? ` (delta ${(delta / 1000).toFixed(2)}s)` : '') +
      (r.ok ? '' : ` — ${JSON.stringify(r.body)}`)
  );
  previous = r.doneAt;
}

const allOk = results.every(r => r.ok);
// SEND_DELAY_MS=1000 + jitter 0-500ms; 0.95s de tolerância pra ruído de rede local.
const spaced = minDelta >= 950;
console.log('');
if (allOk && spaced) {
  console.log(`PASS: ${n} envios ok, menor espaçamento ${(minDelta / 1000).toFixed(2)}s (>=1s com jitter).`);
} else {
  console.log(
    `FAIL: ${allOk ? '' : 'houve envio com erro. '}` +
      (spaced ? '' : `menor espaçamento ${(minDelta / 1000).toFixed(2)}s (< 0.95s — throttle não segurou).`)
  );
  process.exit(1);
}
