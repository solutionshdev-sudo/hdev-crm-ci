import { expect, it } from 'vitest';
import {
  buildEchoPayload,
  buildMessagesPayload,
  messageTimestampSeconds,
  selectHistoryMessages,
  translateMessageContent,
  type CloudMessage,
} from './inbound.js';

it('texto simples vira type text', () => {
  expect(translateMessageContent({ conversation: 'oi' })).toEqual({
    type: 'text',
    text: { body: 'oi' },
  });
});

it('tipos silenciosos continuam descartados (null)', () => {
  expect(translateMessageContent({ reactionMessage: {} })).toBeNull();
  expect(translateMessageContent({ protocolMessage: {} })).toBeNull();
  expect(
    translateMessageContent({ messageContextInfo: {}, pollUpdateMessage: {} })
  ).toBeNull();
});

it('conteúdo real sem tradução vira unsupported em vez de sumir', () => {
  expect(
    translateMessageContent({ contactMessage: { displayName: 'Fulano' } })
  ).toEqual({ type: 'unsupported' });
});

it('mídia sem download (falha) vira unsupported, não perde a mensagem', () => {
  expect(
    translateMessageContent({ imageMessage: { caption: 'foto' } }, undefined)
  ).toEqual({ type: 'unsupported' });
});

it('mídia com download segue como attachment normal', () => {
  expect(
    translateMessageContent(
      { imageMessage: { caption: 'foto' } },
      { mediaId: 'inst:MSG1', mimetype: 'image/jpeg' }
    )
  ).toEqual({
    type: 'image',
    image: { id: 'inst:MSG1', mime_type: 'image/jpeg', caption: 'foto' },
  });
});

it('eco usa field smb_message_echoes com from=negócio e to=contato', () => {
  const message: CloudMessage = {
    from: '5511888888888',
    to: '5511999999999',
    id: 'inst:ECHO1',
    timestamp: '1722400000',
    type: 'text',
    text: { body: 'respondi do celular' },
  };
  const payload = buildEchoPayload('inst', '+5511888888888', message);
  const change = payload.entry[0].changes[0];
  expect(change.field).toBe('smb_message_echoes');
  expect(change.value.message_echoes).toEqual([message]);
  expect(change.value.metadata.display_phone_number).toBe('5511888888888');
  expect('contacts' in change.value).toBe(false);
});

it('messageTimestampSeconds aceita number, Long (toNumber) e lixo', () => {
  expect(messageTimestampSeconds(1722400000)).toBe(1722400000);
  expect(messageTimestampSeconds({ toNumber: () => 1722400000 })).toBe(1722400000);
  expect(messageTimestampSeconds(undefined)).toBe(0);
  expect(messageTimestampSeconds('abc')).toBe(0);
});

it('histórico: filtra janela, grupos e sem id; ordena por timestamp', () => {
  const now = 1_000_000;
  const hourAgo = now - 3600;
  const messages = [
    { key: { remoteJid: 'b@s.whatsapp.net', id: 'B' }, messageTimestamp: hourAgo + 200 },
    { key: { remoteJid: 'a@s.whatsapp.net', id: 'A' }, messageTimestamp: hourAgo + 100 },
    { key: { remoteJid: 'velho@s.whatsapp.net', id: 'V' }, messageTimestamp: now - 90_000 },
    { key: { remoteJid: 'grupo@g.us', id: 'G' }, messageTimestamp: hourAgo + 300 },
    { key: { remoteJid: 'semid@s.whatsapp.net', id: null }, messageTimestamp: hourAgo + 300 },
    { key: { remoteJid: 'lid@lid', id: 'L' }, messageTimestamp: { toNumber: () => hourAgo + 50 } },
  ];

  const selected = selectHistoryMessages(messages, now, 86_400);

  expect(selected.map(item => item.key.id)).toEqual(['L', 'A', 'B']);
});

it('histórico: janela zero ou negativa não deixa passar nada relevante', () => {
  const messages = [
    { key: { remoteJid: 'a@s.whatsapp.net', id: 'A' }, messageTimestamp: 999 },
  ];
  expect(selectHistoryMessages(messages, 1000, 0)).toEqual([]);
});

it('mensagem recebida mantém o shape messages com contacts', () => {
  const message: CloudMessage = {
    from: '5511999999999',
    id: 'inst:MSG1',
    timestamp: '1722400000',
    type: 'text',
    text: { body: 'oi' },
  };
  const payload = buildMessagesPayload(
    'inst',
    '+5511888888888',
    '5511999999999',
    'Cliente',
    message
  );
  const change = payload.entry[0].changes[0];
  expect(change.field).toBe('messages');
  expect(change.value.messages).toEqual([message]);
  expect(change.value.contacts[0].wa_id).toBe('5511999999999');
});
