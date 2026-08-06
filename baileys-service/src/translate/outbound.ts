import type { AnyMessageContent } from '@whiskeysockets/baileys';

// Meta Cloud API send payload -> Baileys sendMessage content. Keeping the HTTP
// contract in Cloud shape lets the Rails provider mirror WhatsappCloudService.
//
// Interactive payloads (buttons/list) are flattened to numbered text: Baileys
// button/list messages render unreliably on current WhatsApp clients, and the
// chatbot answer matcher accepts typed numbers anyway.

export interface CloudSendPayload {
  to: string;
  type?: string;
  text?: { body: string };
  image?: { link: string; caption?: string };
  audio?: { link: string; voice?: boolean };
  video?: { link: string; caption?: string };
  document?: {
    link: string;
    caption?: string;
    filename?: string;
    mime_type?: string;
  };
  interactive?: {
    body?: { text?: string };
    action?: {
      buttons?: Array<{ reply?: { id?: string; title?: string } }>;
      sections?: Array<{ rows?: Array<{ id?: string; title?: string }> }>;
      button?: string;
    };
  };
}

export function toJid(to: string): string {
  return `${to.replace(/\D/g, '')}@s.whatsapp.net`;
}

export function translateOutbound(payload: CloudSendPayload): AnyMessageContent {
  if (payload.text?.body != null) return { text: payload.text.body };

  if (payload.image?.link) {
    return {
      image: { url: payload.image.link },
      caption: payload.image.caption,
    };
  }

  if (payload.audio?.link) {
    return {
      audio: { url: payload.audio.link },
      ptt: payload.audio.voice !== false,
      mimetype: 'audio/ogg; codecs=opus',
    };
  }

  if (payload.video?.link) {
    return {
      video: { url: payload.video.link },
      caption: payload.video.caption,
    };
  }

  if (payload.document?.link) {
    return {
      document: { url: payload.document.link },
      mimetype: payload.document.mime_type || 'application/octet-stream',
      fileName: payload.document.filename || 'document',
      caption: payload.document.caption,
    };
  }

  if (payload.interactive) {
    const body = payload.interactive.body?.text || '';
    const options =
      payload.interactive.action?.buttons?.map(
        item => item.reply?.title || ''
      ) ||
      payload.interactive.action?.sections?.flatMap(
        section => section.rows?.map(row => row.title || '') || []
      ) ||
      [];
    const lines = options.map((title, index) => `${index + 1}. ${title}`);
    return { text: [body, '', ...lines].join('\n').trim() };
  }

  throw new Error('Unsupported outbound payload');
}
