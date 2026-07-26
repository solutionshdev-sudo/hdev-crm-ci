import { createHmac } from 'node:crypto';
import pino from 'pino';

const logger = pino({ name: 'webhook' });

const MAX_ATTEMPTS = 5;

// Fire-and-forget with retry. Rails answers 200 as soon as the signature
// checks out (processing happens in Sidekiq), so failures here mean network
// or a Rails outage — backoff and retry, then drop with a log.
export async function deliverWebhook(
  url: string,
  secret: string,
  event: string,
  instanceId: string,
  payload: unknown
): Promise<void> {
  const body = JSON.stringify(payload);
  const signature = createHmac('sha256', secret).update(body).digest('hex');

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt += 1) {
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Baileys-Instance': instanceId,
          'X-Baileys-Event': event,
          'X-Baileys-Signature': `sha256=${signature}`,
        },
        body,
        signal: AbortSignal.timeout(10_000),
      });
      if (response.ok) return;
      logger.warn(
        { instanceId, event, status: response.status, attempt },
        'webhook rejected'
      );
      // 401 = assinatura/segredo errado; repetir não conserta.
      if (response.status === 401) return;
    } catch (error) {
      logger.warn({ instanceId, event, attempt, error: String(error) }, 'webhook failed');
    }
    await new Promise(resolve => {
      setTimeout(resolve, Math.min(2 ** attempt * 1000, 30_000));
    });
  }
  logger.error({ instanceId, event }, 'webhook dropped after max attempts');
}
