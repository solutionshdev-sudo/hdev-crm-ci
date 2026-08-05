import { createHmac } from 'node:crypto';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { deliverWebhook } from './webhook.js';

// Silencia o pino real (warn/error em stdout) sem tocar em src/webhook.ts —
// so troca o transporte de log dentro do teste.
vi.mock('pino', () => ({
  default: () => ({ warn: vi.fn(), error: vi.fn(), info: vi.fn() }),
}));

// Nao ha parser/verificador HMAC dentro de baileys-service: quem recebe e
// verifica a assinatura e o Webhooks::BaileysController no hdevCRM (Rails,
// fora do escopo desta task). O unico codigo de assinatura que vive aqui e o
// lado emissor em deliverWebhook — estes specs cobrem o contraparte possivel
// dentro do escopo: assinatura calculada corretamente (o que o Rails validaria
// como valida), o encerramento sem retry quando o receptor rejeita por 401
// (assinatura invalida, terminal por definicao no proprio codigo) e o corpo
// que nao serializa (malformado).
describe('deliverWebhook', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('assina o corpo bruto com HMAC-SHA256 do secret e para na primeira resposta 200 (assinatura valida aceita)', async () => {
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, status: 200 });
    vi.stubGlobal('fetch', fetchMock);

    const payload = { event: 'messages', foo: 'bar' };
    await deliverWebhook('https://rails.example/webhooks/baileys', 'segredo', 'messages', 'inst-1', payload);

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe('https://rails.example/webhooks/baileys');

    const body = JSON.stringify(payload);
    const expectedSignature = createHmac('sha256', 'segredo').update(body).digest('hex');
    expect(init.body).toBe(body);
    expect(init.headers['X-Baileys-Signature']).toBe(`sha256=${expectedSignature}`);
    expect(init.headers['X-Baileys-Instance']).toBe('inst-1');
    expect(init.headers['X-Baileys-Event']).toBe('messages');
  });

  it('para apos uma unica tentativa quando o receptor responde 401 (assinatura invalida e terminal, nao repete)', async () => {
    const fetchMock = vi.fn().mockResolvedValue({ ok: false, status: 401 });
    vi.stubGlobal('fetch', fetchMock);

    await deliverWebhook('https://rails.example/webhooks/baileys', 'segredo-errado', 'messages', 'inst-1', { a: 1 });

    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('rejeita quando o payload nao serializa em JSON (corpo malformado)', async () => {
    vi.stubGlobal('fetch', vi.fn());
    const circular: Record<string, unknown> = {};
    circular.self = circular;

    await expect(
      deliverWebhook('https://rails.example/webhooks/baileys', 'segredo', 'messages', 'inst-1', circular)
    ).rejects.toThrow(/circular structure/i);
  });
});
