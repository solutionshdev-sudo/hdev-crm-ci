import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildEchoPayload,
  buildMessagesPayload,
  messageTimestampSeconds,
  selectHistoryMessages,
  translateMessageContent,
  type CloudMessage,
} from './inbound.js';

test('texto simples vira type text', () => {
  assert.deepEqual(translateMessageContent({ conversation: 'oi' }), {
    type: 'text',
    text: { body: 'oi' },
  });
});

test('tipos silenciosos continuam descartados (null)', () => {
  assert.equal(translateMessageContent({ reactionMessage: {} }), null);
  assert.equal(translateMessageContent({ protocolMessage: {} }), null);
  assert.equal(
    translateMessageContent({ messageContextInfo: {}, pollUpdateMessage: {} }),
    null
  );
});

test('conteúdo real sem tradução vira unsupported em vez de sumir', () => {
  assert.deepEqual(
    translateMessageContent({ contactMessage: { displayName: 'Fulano' } }),
    { type: 'unsupported' }
  );
});

test('mídia sem download (falha) vira unsupported, não perde a mensagem', () => {
  assert.deepEqual(
    translateMessageContent({ imageMessage: { caption: 'foto' } }, undefined),
    { type: 'unsupported' }
  );
});

test('mídia com download segue como attachment normal', () => {
  assert.deepEqual(
    translateMessageContent(
      { imageMessage: { caption: 'foto' } },
      { mediaId: 'inst:MSG1', mimetype: 'image/jpeg' }
    ),
    {
      type: 'image',
      image: { id: 'inst:MSG1', mime_type: 'image/jpeg', caption: 'foto' },
    }
  );
});

test('eco usa field smb_message_echoes com from=negócio e to=contato', () => {
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
  assert.equal(change.field, 'smb_message_echoes');
  assert.deepEqual(change.value.message_echoes, [message]);
  assert.equal(change.value.metadata.display_phone_number, '5511888888888');
  assert.ok(!('contacts' in change.value));
});

test('messageTimestampSeconds aceita number, Long (toNumber) e lixo', () => {
  assert.equal(messageTimestampSeconds(1722400000), 1722400000);
  assert.equal(messageTimestampSeconds({ toNumber: () => 1722400000 }), 1722400000);
  assert.equal(messageTimestampSeconds(undefined), 0);
  assert.equal(messageTimestampSeconds('abc'), 0);
});

test('histórico: filtra janela, grupos e sem id; ordena por timestamp', () => {
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

  assert.deepEqual(
    selected.map(item => item.key.id),
    ['L', 'A', 'B']
  );
});

test('histórico: janela zero ou negativa não deixa passar nada relevante', () => {
  const messages = [
    { key: { remoteJid: 'a@s.whatsapp.net', id: 'A' }, messageTimestamp: 999 },
  ];
  assert.deepEqual(selectHistoryMessages(messages, 1000, 0), []);
});

test('mensagem recebida mantém o shape messages com contacts', () => {
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
  assert.equal(change.field, 'messages');
  assert.deepEqual(change.value.messages, [message]);
  assert.equal(change.value.contacts[0].wa_id, '5511999999999');
});
