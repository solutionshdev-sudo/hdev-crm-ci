import pino from 'pino';
import { Instance } from './instance.js';
import {
  hasRegisteredCreds,
  listInstanceIds,
  loadConfig,
  removeInstanceDir,
  saveConfig,
} from './store.js';
import type { InstanceConfig } from '../types.js';

const logger = pino({ name: 'manager' });

const instances = new Map<string, Instance>();

export function getInstance(id: string): Instance | undefined {
  return instances.get(id);
}

export function allInstances(): Instance[] {
  return [...instances.values()];
}

// Idempotent: re-provisioning an existing id updates its config in place
// (webhook secret rotation, proxy swap) instead of duplicating the session.
export function provisionInstance(config: InstanceConfig): {
  instance: Instance;
  created: boolean;
} {
  const existing = instances.get(config.id);
  if (existing) {
    existing.updateConfig(config);
    return { instance: existing, created: false };
  }
  saveConfig(config);
  const instance = new Instance(config);
  instances.set(config.id, instance);
  return { instance, created: true };
}

export async function destroyInstance(id: string): Promise<boolean> {
  const instance = instances.get(id);
  if (instance) {
    await instance.destroy();
    instances.delete(id);
  }
  removeInstanceDir(id);
  return !!instance;
}

// Boot: recreate every persisted instance and reconnect the ones that have
// credentials. Instances still waiting for pairing stay disconnected until
// the dashboard asks for a QR again.
export async function loadAll(): Promise<void> {
  for (const id of listInstanceIds()) {
    const config = loadConfig(id);
    if (!config) continue;
    const instance = new Instance(config);
    instances.set(id, instance);
    // Sem credencial pareada, connect() aqui gera QR que ninguém está olhando,
    // expira ("QR refs attempts ended"), reconecta e recomeça — para sempre, e
    // no mesmo event loop das instâncias que funcionam. Fica registrada e
    // parada até o painel pedir um QR.
    if (!hasRegisteredCreds(id)) continue;
    instance.connect().catch(error => {
      logger.error({ id, error: String(error) }, 'boot reconnect failed');
    });
  }
  logger.info({ count: instances.size }, 'instances loaded');
}
