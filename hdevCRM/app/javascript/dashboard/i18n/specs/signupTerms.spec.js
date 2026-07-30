import { describe, it, expect } from 'vitest';

// O link de termos do cadastro sai de TERMS_URL/PRIVACY_URL
// (installation_configs), que o Agency sobrescreve por agência. Se uma
// tradução cravar a URL no texto em vez de usar o placeholder, o override
// morre em silêncio — foi assim que a tradução pt-BR desligou a configuração
// sem ninguém notar. Este teste é o que faz esse erro aparecer.
const signupLocales = import.meta.glob('../locale/*/signup.json', {
  eager: true,
});

const entries = Object.entries(signupLocales).map(([path, mod]) => [
  path.match(/locale\/([^/]+)\//)[1],
  (mod.default ?? mod).REGISTER?.TERMS_ACCEPT,
]);

describe('REGISTER.TERMS_ACCEPT', () => {
  it('cobre todos os locales', () => {
    expect(entries.length).toBeGreaterThan(50);
  });

  it.each(entries)('%s usa os placeholders e não crava URL', (locale, text) => {
    expect(text, `${locale}: chave ausente`).toBeTruthy();
    expect(text).toContain('{termsUrl}');
    expect(text).toContain('{privacyUrl}');
    expect(text).not.toMatch(/https?:\/\//);
  });
});
