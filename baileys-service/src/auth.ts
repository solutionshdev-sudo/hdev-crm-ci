import type { FastifyReply, FastifyRequest } from 'fastify';
import { timingSafeEqual } from 'node:crypto';

const API_KEY = process.env.BAILEYS_API_KEY || '';

export function requireApiKey(
  request: FastifyRequest,
  reply: FastifyReply,
  done: (error?: Error) => void
): void {
  if (!API_KEY) {
    reply.code(500).send({ error: 'BAILEYS_API_KEY is not configured' });
    return;
  }
  const header = request.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  const expected = Buffer.from(API_KEY);
  const received = Buffer.from(token);
  const valid =
    expected.length === received.length && timingSafeEqual(expected, received);
  if (!valid) {
    reply.code(401).send({ error: 'unauthorized' });
    return;
  }
  done();
}
