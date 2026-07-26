import makeWASocket, {
  DisconnectReason,
  downloadMediaMessage,
  useMultiFileAuthState,
  type WASocket,
  type WAMessage,
} from '@whiskeysockets/baileys';
import { Boom } from '@hapi/boom';
import pino from 'pino';
import { buildAgent } from './proxy.js';
import { authDir, removeAuthState, saveConfig } from './store.js';
import { putMedia } from '../media-cache.js';
import { deliverWebhook } from '../webhook.js';
import {
  buildMessagesPayload,
  buildStatusesPayload,
  isDirectUserJid,
  jidToNumber,
  prefixedId,
  translateMessageContent,
  translateStatus,
  type CloudMessage,
} from '../translate/inbound.js';
import { toJid, translateOutbound, type CloudSendPayload } from '../translate/outbound.js';
import type { InstanceConfig, InstanceSnapshot, InstanceStatus } from '../types.js';

const logger = pino({ name: 'instance' });

// Outbound pacing: ~1 msg/s with jitter. Blasting at machine speed is the
// fastest way to get an unofficial number banned.
const SEND_DELAY_MS = 1000;

const MEDIA_TYPES = [
  'imageMessage',
  'videoMessage',
  'audioMessage',
  'documentMessage',
  'stickerMessage',
] as const;

export class Instance {
  config: InstanceConfig;

  status: InstanceStatus = 'disconnected';

  qr: string | null = null;

  pairingCode: string | null = null;

  jid: string | null = null;

  lastError: string | null = null;

  lastDisconnectReason: string | null = null;

  private socket: WASocket | null = null;

  private reconnectAttempts = 0;

  private stopped = false;

  private sendChain: Promise<unknown> = Promise.resolve();

  constructor(config: InstanceConfig) {
    this.config = config;
  }

  snapshot(): InstanceSnapshot {
    return {
      id: this.config.id,
      status: this.status,
      qr: this.qr,
      pairingCode: this.pairingCode,
      jid: this.jid,
      phoneNumber: this.config.phoneNumber,
      lastError: this.lastError,
      lastDisconnectReason: this.lastDisconnectReason,
    };
  }

  updateConfig(config: InstanceConfig): void {
    const proxyChanged = config.proxyUrl !== this.config.proxyUrl;
    this.config = config;
    saveConfig(config);
    // A proxy swap needs a fresh socket bound to the new agent.
    if (proxyChanged && this.socket) void this.connect();
  }

  async connect(usePairingCode?: boolean): Promise<void> {
    this.stopped = false;
    await this.teardownSocket();
    this.setStatus('connecting');
    this.qr = null;
    this.pairingCode = null;
    this.lastError = null;

    const { state, saveCreds } = await useMultiFileAuthState(authDir(this.config.id));
    const agent = buildAgent(this.config.proxyUrl);
    const wantsPairingCode =
      usePairingCode ?? this.config.pairingMethod === 'code';

    const socket = makeWASocket({
      auth: state,
      agent,
      fetchAgent: agent,
      logger: logger.child({ instance: this.config.id, level: 'warn' }),
      markOnlineOnConnect: false,
      syncFullHistory: false,
      browser: ['Hdev CRM', 'Chrome', '1.0.0'],
    });
    this.socket = socket;

    socket.ev.on('creds.update', saveCreds);

    socket.ev.on('connection.update', update => {
      void this.handleConnectionUpdate(update, socket, wantsPairingCode);
    });

    socket.ev.on('messages.upsert', upsert => {
      if (upsert.type !== 'notify') return;
      for (const message of upsert.messages) void this.handleIncoming(message);
    });

    socket.ev.on('messages.update', updates => {
      void this.handleStatusUpdates(updates);
    });
  }

  async logout(): Promise<void> {
    this.stopped = true;
    try {
      await this.socket?.logout();
    } catch (error) {
      logger.warn({ id: this.config.id, error: String(error) }, 'logout failed');
    }
    await this.teardownSocket();
    removeAuthState(this.config.id);
    this.jid = null;
    this.setStatus('disconnected', 'logged_out');
  }

  async destroy(): Promise<void> {
    this.stopped = true;
    try {
      await this.socket?.logout();
    } catch {
      // best effort — the number may already be unlinked
    }
    await this.teardownSocket();
  }

  // Serialized, paced sends. Returns the prefixed message id.
  sendMessage(payload: CloudSendPayload): Promise<{ id: string }> {
    const task = this.sendChain.then(async () => {
      if (!this.socket || this.status !== 'connected') {
        throw new Error(`Instance ${this.config.id} is not connected`);
      }
      const jid = toJid(payload.to);
      const content = translateOutbound(payload);
      await this.socket.sendPresenceUpdate('composing', jid).catch(() => {});
      const result = await this.socket.sendMessage(jid, content);
      const rawId = result?.key?.id;
      if (!rawId) throw new Error('sendMessage returned no id');
      await new Promise(resolve => {
        setTimeout(resolve, SEND_DELAY_MS + Math.random() * 500);
      });
      return { id: prefixedId(this.config.id, rawId) };
    });
    // Keep the chain alive even when a send fails.
    this.sendChain = task.catch(() => {});
    return task;
  }

  private async handleConnectionUpdate(
    update: {
      connection?: string;
      lastDisconnect?: { error?: Error | undefined };
      qr?: string;
    },
    socket: WASocket,
    wantsPairingCode: boolean
  ): Promise<void> {
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      if (wantsPairingCode && !socket.authState.creds.registered) {
        try {
          this.pairingCode = await socket.requestPairingCode(
            this.config.phoneNumber.replace(/\D/g, '')
          );
          this.setStatus('pairing');
        } catch (error) {
          this.lastError = String(error);
          this.qr = qr;
          this.setStatus('qr');
        }
      } else {
        this.qr = qr;
        this.setStatus('qr');
      }
    }

    if (connection === 'open') {
      this.reconnectAttempts = 0;
      this.qr = null;
      this.pairingCode = null;
      this.jid = socket.user?.id || null;
      this.setStatus('connected');
    }

    if (connection === 'close') {
      const statusCode = (lastDisconnect?.error as Boom | undefined)?.output
        ?.statusCode;
      const loggedOut = statusCode === DisconnectReason.loggedOut;
      this.lastDisconnectReason = loggedOut
        ? 'logged_out'
        : `code_${statusCode ?? 'unknown'}`;

      if (loggedOut) {
        removeAuthState(this.config.id);
        this.jid = null;
        this.setStatus('disconnected');
        return;
      }
      if (this.stopped) {
        this.setStatus('disconnected');
        return;
      }
      // Exponential backoff with a 60s ceiling and jitter.
      const delay =
        Math.min(1000 * 2 ** this.reconnectAttempts, 60_000) +
        Math.random() * 1000;
      this.reconnectAttempts += 1;
      this.setStatus('connecting');
      setTimeout(() => {
        if (!this.stopped) void this.connect();
      }, delay);
    }
  }

  private async handleIncoming(message: WAMessage): Promise<void> {
    try {
      const jid = message.key.remoteJid;
      // v1: direct user chats only — no groups, no status broadcast, no self.
      if (!isDirectUserJid(jid) || message.key.fromMe) return;
      if (!message.message || !message.key.id) return;

      const media = await this.downloadMedia(message);
      const content = translateMessageContent(message.message, media);
      if (!content) return;

      const cloudMessage: CloudMessage = {
        from: jidToNumber(jid as string),
        id: prefixedId(this.config.id, message.key.id),
        timestamp: String(
          Number(message.messageTimestamp) || Math.floor(Date.now() / 1000)
        ),
        ...content,
      } as CloudMessage;

      await deliverWebhook(
        this.config.webhookUrl,
        this.config.webhookSecret,
        'messages',
        this.config.id,
        buildMessagesPayload(
          this.config.id,
          this.config.phoneNumber,
          jidToNumber(jid as string),
          message.pushName || undefined,
          cloudMessage
        )
      );
    } catch (error) {
      logger.error(
        { id: this.config.id, error: String(error) },
        'incoming message failed'
      );
    }
  }

  private async handleStatusUpdates(
    updates: Array<{ key: WAMessage['key']; update: Partial<WAMessage> }>
  ): Promise<void> {
    const statuses = updates
      .filter(item => item.key.fromMe && isDirectUserJid(item.key.remoteJid))
      .map(item => {
        const status = translateStatus(item.update.status as number | undefined);
        if (!status || !item.key.id) return null;
        return {
          id: prefixedId(this.config.id, item.key.id),
          status,
          recipientId: jidToNumber(item.key.remoteJid as string),
        };
      })
      .filter((item): item is NonNullable<typeof item> => item !== null);

    if (!statuses.length) return;
    await deliverWebhook(
      this.config.webhookUrl,
      this.config.webhookSecret,
      'statuses',
      this.config.id,
      buildStatusesPayload(this.config.id, this.config.phoneNumber, statuses)
    );
  }

  private async downloadMedia(
    message: WAMessage
  ): Promise<{ mediaId: string; mimetype: string; filename?: string } | undefined> {
    const content = message.message;
    if (!content) return undefined;
    const mediaNode = MEDIA_TYPES.map(type => content[type]).find(Boolean) as
      | { mimetype?: string; fileName?: string }
      | undefined;
    if (!mediaNode) return undefined;

    const buffer = (await downloadMediaMessage(message, 'buffer', {})) as Buffer;
    const mediaId = prefixedId(this.config.id, message.key.id as string);
    const mimetype = mediaNode.mimetype || 'application/octet-stream';
    putMedia(mediaId, buffer, mimetype, mediaNode.fileName);
    return { mediaId, mimetype, filename: mediaNode.fileName };
  }

  private setStatus(status: InstanceStatus, reason?: string): void {
    const changed = this.status !== status;
    this.status = status;
    if (reason) this.lastDisconnectReason = reason;
    if (!changed) return;
    void deliverWebhook(
      this.config.webhookUrl,
      this.config.webhookSecret,
      'connection.update',
      this.config.id,
      {
        object: 'baileys_connection',
        entry: [
          {
            id: this.config.id,
            changes: [
              {
                field: 'connection',
                value: {
                  status,
                  qr: this.qr,
                  pairing_code: this.pairingCode,
                  jid: this.jid,
                  disconnect_reason: this.lastDisconnectReason,
                },
              },
            ],
          },
        ],
      }
    );
  }

  private async teardownSocket(): Promise<void> {
    if (!this.socket) return;
    try {
      this.socket.ev.removeAllListeners('connection.update');
      this.socket.ev.removeAllListeners('messages.upsert');
      this.socket.ev.removeAllListeners('messages.update');
      this.socket.end(undefined);
    } catch {
      // socket already dead
    }
    this.socket = null;
  }
}
