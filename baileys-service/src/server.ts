import Fastify from 'fastify';
import pino from 'pino';
import { requireApiKey } from './auth.js';
import { allInstances, destroyInstance, getInstance, loadAll, provisionInstance } from './instances/manager.js';
import { getMedia } from './media-cache.js';
import type { CloudSendPayload } from './translate/outbound.js';
import type { InstanceConfig } from './types.js';

const logger = pino({ name: 'server' });
const app = Fastify({ logger: false });

// Everything except /health requires the shared API key.
app.addHook('onRequest', (request, reply, done) => {
  if (request.url === '/health') {
    done();
    return;
  }
  requireApiKey(request, reply, done);
});

app.get('/health', async () => {
  const instances = allInstances();
  return {
    ok: true,
    instances: {
      total: instances.length,
      connected: instances.filter(item => item.status === 'connected').length,
    },
  };
});

interface ProvisionBody {
  id: string;
  phoneNumber: string;
  webhookUrl: string;
  webhookSecret: string;
  proxyUrl?: string | null;
  pairingMethod?: 'qr' | 'code';
}

app.post<{ Body: ProvisionBody }>('/instances', async (request, reply) => {
  const body = request.body;
  if (!body?.id || !body.phoneNumber || !body.webhookUrl || !body.webhookSecret) {
    reply.code(422);
    return { error: 'id, phoneNumber, webhookUrl and webhookSecret are required' };
  }
  const config: InstanceConfig = {
    id: body.id,
    phoneNumber: body.phoneNumber,
    webhookUrl: body.webhookUrl,
    webhookSecret: body.webhookSecret,
    proxyUrl: body.proxyUrl || null,
    pairingMethod: body.pairingMethod || 'qr',
  };
  const { instance, created } = provisionInstance(config);
  reply.code(created ? 201 : 200);
  return { id: instance.config.id, status: instance.status };
});

app.get<{ Params: { id: string } }>('/instances/:id', async (request, reply) => {
  const instance = getInstance(request.params.id);
  if (!instance) {
    reply.code(404);
    return { error: 'instance not found' };
  }
  return instance.snapshot();
});

app.post<{ Params: { id: string }; Body: { usePairingCode?: boolean } }>(
  '/instances/:id/connect',
  async (request, reply) => {
    const instance = getInstance(request.params.id);
    if (!instance) {
      reply.code(404);
      return { error: 'instance not found' };
    }
    await instance.connect(request.body?.usePairingCode);
    return instance.snapshot();
  }
);

app.post<{ Params: { id: string } }>('/instances/:id/logout', async (request, reply) => {
  const instance = getInstance(request.params.id);
  if (!instance) {
    reply.code(404);
    return { error: 'instance not found' };
  }
  await instance.logout();
  return instance.snapshot();
});

app.delete<{ Params: { id: string } }>('/instances/:id', async request => {
  const removed = await destroyInstance(request.params.id);
  return { removed };
});

app.post<{ Params: { id: string }; Body: CloudSendPayload }>(
  '/instances/:id/messages',
  async (request, reply) => {
    const instance = getInstance(request.params.id);
    if (!instance) {
      reply.code(404);
      return { error: 'instance not found' };
    }
    try {
      const { id } = await instance.sendMessage(request.body);
      return { messages: [{ id }] };
    } catch (error) {
      reply.code(422);
      return { error: String(error) };
    }
  }
);

app.get<{ Params: { id: string; mediaId: string } }>(
  '/instances/:id/media/:mediaId',
  async (request, reply) => {
    const media = getMedia(request.params.mediaId);
    if (!media) {
      reply.code(404);
      return { error: 'media not found or expired' };
    }
    reply.header('Content-Type', media.mimetype);
    if (media.filename) {
      reply.header(
        'Content-Disposition',
        `attachment; filename="${encodeURIComponent(media.filename)}"`
      );
    }
    return reply.send(media.buffer);
  }
);

const port = Number(process.env.PORT || 3025);

loadAll()
  .then(() => app.listen({ port, host: '0.0.0.0' }))
  .then(() => logger.info({ port }, 'baileys-service up'))
  .catch(error => {
    logger.error({ error: String(error) }, 'boot failed');
    process.exit(1);
  });
