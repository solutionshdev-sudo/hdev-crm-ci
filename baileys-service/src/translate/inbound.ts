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

interface MediaRef {
  mediaId: string;
  mimetype: string;
  filename?: string;
}

// Maps the Baileys message content to the Cloud API `messages[0]` entry.
// Returns null for content we deliberately skip in v1 (reactions, polls,
// group system messages, protocol messages).
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

  return null;
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
