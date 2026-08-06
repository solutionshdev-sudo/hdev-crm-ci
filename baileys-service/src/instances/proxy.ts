import { HttpsProxyAgent } from 'https-proxy-agent';
import { SocksProxyAgent } from 'socks-proxy-agent';
import type { Agent } from 'node:https';

// One agent per proxy URL. Changing the proxy requires recreating the socket —
// the manager tears the instance down and reconnects with the new agent.
// The cast matches what Baileys expects (an https.Agent); both proxy agents
// are drop-in replacements at runtime.
export function buildAgent(proxyUrl?: string | null): Agent | undefined {
  if (!proxyUrl) return undefined;
  const url = new URL(proxyUrl);
  if (url.protocol.startsWith('socks')) {
    return new SocksProxyAgent(proxyUrl) as unknown as Agent;
  }
  if (url.protocol === 'http:' || url.protocol === 'https:') {
    return new HttpsProxyAgent(proxyUrl) as unknown as Agent;
  }
  throw new Error(`Unsupported proxy protocol: ${url.protocol}`);
}
