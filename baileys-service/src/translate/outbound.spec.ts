import { describe, expect, it } from 'vitest';
import { toJid, translateOutbound, type CloudSendPayload } from './outbound.js';

describe('toJid', () => {
  it('strips formatting characters and appends the WhatsApp JID suffix', () => {
    expect(toJid('+55 (11) 91234-5678')).toBe('5511912345678@s.whatsapp.net');
  });

  it('passes through an already digit-only number', () => {
    expect(toJid('5511912345678')).toBe('5511912345678@s.whatsapp.net');
  });
});

describe('translateOutbound', () => {
  it('translates a text payload', () => {
    const payload: CloudSendPayload = { to: '123', type: 'text', text: { body: 'oi' } };
    expect(translateOutbound(payload)).toEqual({ text: 'oi' });
  });

  it('translates an image payload with caption', () => {
    const payload: CloudSendPayload = {
      to: '123',
      image: { link: 'https://x/img.png', caption: 'legenda' },
    };
    expect(translateOutbound(payload)).toEqual({
      image: { url: 'https://x/img.png' },
      caption: 'legenda',
    });
  });

  it('translates an audio payload defaulting to ptt (voice note) when voice is not set', () => {
    const payload: CloudSendPayload = { to: '123', audio: { link: 'https://x/a.ogg' } };
    expect(translateOutbound(payload)).toEqual({
      audio: { url: 'https://x/a.ogg' },
      ptt: true,
      mimetype: 'audio/ogg; codecs=opus',
    });
  });

  it('translates an audio payload as a regular (non-ptt) file when voice:false', () => {
    const payload: CloudSendPayload = {
      to: '123',
      audio: { link: 'https://x/a.ogg', voice: false },
    };
    expect(translateOutbound(payload)).toEqual({
      audio: { url: 'https://x/a.ogg' },
      ptt: false,
      mimetype: 'audio/ogg; codecs=opus',
    });
  });

  it('translates a video payload with caption', () => {
    const payload: CloudSendPayload = {
      to: '123',
      video: { link: 'https://x/v.mp4', caption: 'legenda' },
    };
    expect(translateOutbound(payload)).toEqual({
      video: { url: 'https://x/v.mp4' },
      caption: 'legenda',
    });
  });

  it('translates a document payload, defaulting mimetype/filename when missing', () => {
    const payload: CloudSendPayload = { to: '123', document: { link: 'https://x/doc' } };
    expect(translateOutbound(payload)).toEqual({
      document: { url: 'https://x/doc' },
      mimetype: 'application/octet-stream',
      fileName: 'document',
      caption: undefined,
    });
  });

  it('translates a document payload honoring provided mimetype/filename/caption', () => {
    const payload: CloudSendPayload = {
      to: '123',
      document: {
        link: 'https://x/relatorio.pdf',
        mime_type: 'application/pdf',
        filename: 'relatorio.pdf',
        caption: 'segue o relatorio',
      },
    };
    expect(translateOutbound(payload)).toEqual({
      document: { url: 'https://x/relatorio.pdf' },
      mimetype: 'application/pdf',
      fileName: 'relatorio.pdf',
      caption: 'segue o relatorio',
    });
  });

  it('flattens an interactive buttons payload into numbered text (buttons render unreliably in Baileys)', () => {
    const payload: CloudSendPayload = {
      to: '123',
      interactive: {
        body: { text: 'Escolha uma opcao' },
        action: {
          buttons: [
            { reply: { id: '1', title: 'Sim' } },
            { reply: { id: '2', title: 'Nao' } },
          ],
        },
      },
    };
    expect(translateOutbound(payload)).toEqual({
      text: 'Escolha uma opcao\n\n1. Sim\n2. Nao',
    });
  });

  it('flattens an interactive list payload into numbered text', () => {
    const payload: CloudSendPayload = {
      to: '123',
      interactive: {
        body: { text: 'Escolha' },
        action: {
          sections: [{ rows: [{ id: 'a', title: 'A' }, { id: 'b', title: 'B' }] }],
        },
      },
    };
    expect(translateOutbound(payload)).toEqual({ text: 'Escolha\n\n1. A\n2. B' });
  });

  it('throws on an unsupported/unknown payload shape', () => {
    const payload = { to: '123' } as CloudSendPayload;
    expect(() => translateOutbound(payload)).toThrow('Unsupported outbound payload');
  });
});
