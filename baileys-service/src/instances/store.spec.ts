import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

// hasRegisteredCreds le SESSIONS_DIR de uma const de modulo avaliada no
// import, entao o env precisa estar setado ANTES do import — vi.resetModules
// + import dinamico por teste, apontando pra um tmpdir isolado.
describe('hasRegisteredCreds', () => {
  let dir: string;
  let store: typeof import('./store.js');

  beforeEach(async () => {
    dir = mkdtempSync(join(tmpdir(), 'baileys-store-test-'));
    vi.stubEnv('SESSIONS_DIR', dir);
    vi.resetModules();
    store = await import('./store.js');
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    rmSync(dir, { recursive: true, force: true });
  });

  it('returns false when creds.json does not exist yet (instance never attempted pairing)', () => {
    expect(store.hasRegisteredCreds('inst-1')).toBe(false);
  });

  it('returns false when creds.json exists but registered:false — useMultiFileAuthState writes ' +
    'the file on the FIRST pairing attempt, before the pairing actually completes',
  () => {
    mkdirSync(store.authDir('inst-1'), { recursive: true });
    writeFileSync(
      join(store.authDir('inst-1'), 'creds.json'),
      JSON.stringify({ registered: false })
    );
    expect(store.hasRegisteredCreds('inst-1')).toBe(false);
  });

  it('returns true only when creds.json has registered:true', () => {
    mkdirSync(store.authDir('inst-1'), { recursive: true });
    writeFileSync(
      join(store.authDir('inst-1'), 'creds.json'),
      JSON.stringify({ registered: true })
    );
    expect(store.hasRegisteredCreds('inst-1')).toBe(true);
  });

  it('returns false when creds.json is malformed JSON', () => {
    mkdirSync(store.authDir('inst-1'), { recursive: true });
    writeFileSync(join(store.authDir('inst-1'), 'creds.json'), '{not valid json');
    expect(store.hasRegisteredCreds('inst-1')).toBe(false);
  });
});
