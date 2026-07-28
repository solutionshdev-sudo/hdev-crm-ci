import { mkdirSync, readFileSync, writeFileSync, readdirSync, rmSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import type { InstanceConfig } from '../types.js';

export const SESSIONS_DIR = process.env.SESSIONS_DIR || '/data/sessions';

export function instanceDir(id: string): string {
  return join(SESSIONS_DIR, id);
}

export function authDir(id: string): string {
  return join(instanceDir(id), 'auth');
}

export function saveConfig(config: InstanceConfig): void {
  mkdirSync(instanceDir(config.id), { recursive: true });
  writeFileSync(
    join(instanceDir(config.id), 'config.json'),
    JSON.stringify(config, null, 2)
  );
}

export function loadConfig(id: string): InstanceConfig | null {
  const path = join(instanceDir(id), 'config.json');
  if (!existsSync(path)) return null;
  return JSON.parse(readFileSync(path, 'utf8')) as InstanceConfig;
}

export function listInstanceIds(): string[] {
  if (!existsSync(SESSIONS_DIR)) return [];
  return readdirSync(SESSIONS_DIR, { withFileTypes: true })
    .filter(entry => entry.isDirectory())
    .map(entry => entry.name)
    .filter(id => loadConfig(id) !== null);
}

// Pareada de verdade? useMultiFileAuthState grava creds.json já na primeira
// tentativa de registro, com registered:false — a existência do arquivo não diz
// nada. O flag é o mesmo que instance.ts lê em socket.authState.creds.registered.
export function hasRegisteredCreds(id: string): boolean {
  const path = join(authDir(id), 'creds.json');
  if (!existsSync(path)) return false;
  try {
    return JSON.parse(readFileSync(path, 'utf8')).registered === true;
  } catch {
    return false;
  }
}

export function removeInstanceDir(id: string): void {
  rmSync(instanceDir(id), { recursive: true, force: true });
}

export function removeAuthState(id: string): void {
  rmSync(authDir(id), { recursive: true, force: true });
}
