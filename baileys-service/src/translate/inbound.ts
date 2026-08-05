import type { proto } from '@whiskeysockets/baileys';

// Translates a Baileys WAMessage into the Meta Cloud API webhook shape, so the
// Rails side reuses Whatsapp::IncomingMessageWhatsappCloudService untouched.
// Message ids are ALWAYS prefixed with the instance id: the Rails dedupe
// (MESSAGE_SOURCE_KEY + Message.find_by(source_id:)) is global, and raw
// Baileys key.ids are not unique across instances.

export interface CloudMessage {
  from: string;
  id: string;
  timestamp: string;
  type: string;
  [key: string]: unknown;
}

export function jidToNumber(jid: string): string {
  return jid.split('@')[0].split(':')[0];
}

export function isDirectUserJid(jid?: string | null): boolean {
  return !!jid && jid.endsWith('@s.whatsapp.net');
}

export function prefixedId(instanceId: string, rawId: string): string {
  return `${instanceId}:${rawId}`;
}

// messageTimestamp vem como number OU Long (protobuf); Number(Long) é NaN,
// então normalizar aqui pra não descartar mensagem boa por engano.
export function messageTimestampSeconds(ts: unknown): number {
  if (typeof ts === 'number') return ts;
  if (ts && typeof (ts as { toNumber?: unknown }).toNumber === 'function') {
    return (ts as { toNumber: () => number }).toNumber();
  }
  return Number(ts) || 0;
}

interface HistoryMessageShape {
  key: { remoteJid?: string | null; id?: string | null };
  messageTimestamp?: unknown;
}

// Backfill de histórico (messaging-history.set): só chat direto, só mensagens
// dentro da janela, ordenadas por timestamp pra chegar no Rails na ordem da
// conversa. O dedupe fica no Rails (source_id) — repetir sync não duplica.
export function selectHistoryMessages<T extends HistoryMessageShape>(
  messages: T[],
  nowSeconds: number,
  maxAgeSeconds: number
): T[] {
  const cutoff = nowSeconds - maxAgeSeconds;
  return messages
    .filter(message => {
      const jid = message.key.remoteJid;
      if (!jid || !message.key.id) return false;
      if (!isDirectUserJid(jid) && !jid.endsWith('@lid')) return false;
      return messageTimestampSeconds(message.messageTimestamp) >= cutoff;
    })
    .sort(
      (a, b) =>
        messageTimestampSeconds(a.messageTimestamp) -
        messageTimestampSeconds(b.messageTimestamp)
    );
}

interface MediaRef {
  mediaId: string;
  mimetype: string;
  filename?: string;
}

// Tipos sem conteúdo visível pro agente: descartar em silêncio (um placeholder
// por reação/recibo de protocolo viraria spam na conversa).
const SILENT_TYPES = new Set([
  'protocolMessage',
  'reactionMessage',
  'pollUpdateMessage',
  'messageContextInfo',
  'senderKeyDistributionMessage',
]);

// Maps the Baileys message content to the Cloud API `messages[0]` entry.
// Returns null only for the silent types above; anything else we can't
// translate (contact card, poll, media whose download failed) becomes
// type 'unsupported' — the Rails pipeline already renders that as an I18n
// placeholder, so the agent knows something arrived instead of losing it.
export function translateMessageContent(
  message: proto.IMessage,
  media?: MediaRef
): Record<string, unknown> | null {
  const text =
    message.conversation ||
    message.extendedTextMessage?.text ||
    message.ephemeralMessage?.message?.conversation ||
    message.ephemeralMessage?.message?.extendedTextMessage?.text;
  if (text) return { type: 'text', text: { body: text } };

  if (message.buttonsResponseMessage) {
    const reply = message.buttonsResponseMessage;
    return {
      type: 'interactive',
      interactive: {
        type: 'button_reply',
        button_reply: {
          id: reply.selectedButtonId || '',
          title: reply.selectedDisplayText || reply.selectedButtonId || '',
        },
      },
    };
  }

  if (message.templateButtonReplyMessage) {
    const reply = message.templateButtonReplyMessage;
    return {
      type: 'interactive',
      interactive: {
        type: 'button_reply',
        button_reply: {
          id: reply.selectedId || '',
          title: reply.selectedDisplayText || reply.selectedId || '',
        },
      },
    };
  }

  if (message.listResponseMessage) {
    const reply = message.listResponseMessage;
    return {
      type: 'interactive',
      interactive: {
        type: 'list_reply',
        list_reply: {
          id: reply.singleSelectReply?.selectedRowId || '',
          title: reply.title || '',
        },
      },
    };
  }

  if (message.imageMessage && media) {
    return {
      type: 'image',
      image: {
        id: media.mediaId,
        mime_type: media.mimetype,
        caption: message.imageMessage.caption || undefined,
      },
    };
  }

  if (message.stickerMessage && media) {
    return {
      type: 'sticker',
      sticker: { id: media.mediaId, mime_type: media.mimetype },
    };
  }

  if (message.audioMessage && media) {
    return {
      type: 'audio',
      audio: {
        id: media.mediaId,
        mime_type: media.mimetype,
        voice: !!message.audioMessage.ptt,
      },
    };
  }

  if (message.videoMessage && media) {
    return {
      type: 'video',
      video: {
        id: media.mediaId,
        mime_type: media.mimetype,
        caption: message.videoMessage.caption || undefined,
      },
    };
  }

  if (message.documentMessage && media) {
    return {
      type: 'document',
      document: {
        id: media.mediaId,
        mime_type: media.mimetype,
        filename: message.documentMessage.fileName || media.filename,
        caption: message.documentMessage.caption || undefined,
      },
    };
  }

  if (message.locationMessage) {
    return {
      type: 'location',
      location: {
        latitude: message.locationMessage.degreesLatitude,
        longitude: message.locationMessage.degreesLongitude,
        name: message.locationMessage.name || undefined,
        address: message.locationMessage.address || undefined,
      },
    };
  }

  const visible = Object.keys(message).filter(key => !SILENT_TYPES.has(key));
  if (visible.length === 0) return null;
  return { type: 'unsupported' };
}

export function buildMessagesPayload(
  instanceId: string,
  phoneNumber: string,
  senderNumber: string,
  pushName: string | undefined,
  cloudMessage: CloudMessage
) {
  return {
    object: 'whatsapp_business_account',
    entry: [
      {
        id: instanceId,
        changes: [
          {
            field: 'messages',
            value: {
              messaging_product: 'whatsapp',
              metadata: {
                display_phone_number: phoneNumber.replace(/^\+/, ''),
                phone_number_id: instanceId,
              },
              contacts: [
                {
                  profile: { name: pushName || senderNumber },
                  wa_id: senderNumber,
                },
              ],
              messages: [cloudMessage],
            },
          },
        ],
      },
    ],
  };
}

// Eco: mensagem enviada pelo celular da própria conta. Mesmo shape do evento
// de coexistence do Cloud (field smb_message_echoes, `from` = número do
// negócio, `to` = contato, sem array contacts) — o Rails já ingere esse
// formato com outgoing_echo e cria a mensagem como outgoing.
export function buildEchoPayload(
  instanceId: string,
  phoneNumber: string,
  cloudMessage: CloudMessage
) {
  return {
    object: 'whatsapp_business_account',
    entry: [
      {
        id: instanceId,
        changes: [
          {
            field: 'smb_message_echoes',
            value: {
              messaging_product: 'whatsapp',
              metadata: {
                display_phone_number: phoneNumber.replace(/^\+/, ''),
                phone_number_id: instanceId,
              },
              message_echoes: [cloudMessage],
            },
          },
        ],
      },
    ],
  };
}

const STATUS_MAP: Record<number, string> = {
  2: 'sent',
  3: 'delivered',
  4: 'read',
  5: 'read',
};

export function translateStatus(status?: number | null): string | null {
  if (status == null) return null;
  return STATUS_MAP[status] || null;
}

export function buildStatusesPayload(
  instanceId: string,
  phoneNumber: string,
  statuses: Array<{ id: string; status: string; recipientId: string }>
) {
  return {
    object: 'whatsapp_business_account',
    entry: [
      {
        id: instanceId,
        changes: [
          {
            field: 'messages',
            value: {
              messaging_product: 'whatsapp',
              metadata: {
                display_phone_number: phoneNumber.replace(/^\+/, ''),
                phone_number_id: instanceId,
              },
              statuses: statuses.map(item => ({
                id: item.id,
                status: item.status,
                recipient_id: item.recipientId,
                timestamp: String(Math.floor(Date.now() / 1000)),
              })),
            },
          },
        ],
      },
    ],
  };
}
