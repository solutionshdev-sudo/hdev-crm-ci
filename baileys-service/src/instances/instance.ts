import makeWASocket, {
  DisconnectReason,
  downloadMediaMessage,
  fetchLatestWaWebVersion,
  useMultiFileAuthState,
  type WASocket,
  type WAMessage,
  type WAVersion,
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

// Fechamentos em que a credencial salva não serve mais. Reconectar com ela só
// repete o mesmo erro — e prende a instância num beco sem saída, porque o
// Baileys só emite QR quando `creds.registered` é false: com credencial morta no
// disco ele vai direto pra "logging in...", leva o failure de volta e o painel
// fica em "Conectando..." pra sempre. Apagar a auth state é o que faz o botão
// "Gerar QR code" voltar a produzir QR.
//
// 405 não está no enum do Baileys: é o `<failure reason="405">` que o WhatsApp
// manda quando recusa o login daquele device (sessão invalidada sem logout
// limpo). Terminal como o 401, só sem a cortesia de dizer isso.
const FATAL_CLOSE_CODES = new Set<number>([
  DisconnectReason.loggedOut, // 401 — desvinculado no celular
  DisconnectReason.forbidden, // 403 — número bloqueado pelo WhatsApp
  DisconnectReason.multideviceMismatch, // 411
  405,
]);

// A versão do cliente WhatsApp Web que o Baileys hardcoda envelhece: quando o
// WhatsApp para de aceitar aquele número, TODO handshake volta com
// `failure reason="405"` — login e registro novo — e nem QR sai. Foi o que
// derrubou a 6.x (commit 5af436b, "resolvido" subindo pra 7.0.0-rc13) e o que
// derrubou a rc13 depois: ela pede 2.3000.1035194821, e o WhatsApp já estava
// em 2.3000.1044104838. Bumpar a dependência a cada vez é enxugar gelo — a
// versão se pergunta ao WhatsApp na hora de conectar.
//
// Não passa pelo proxy da instância: é um GET público de versão, não tráfego
// da conta. Se falhar, cai na última versão boa desta réplica e, na falta
// dela, no default do Baileys (undefined = a lib decide).
let lastKnownVersion: WAVersion | undefined;

const VERSION_FETCH_TIMEOUT_MS = 5000;

async function resolveWaVersion(): Promise<WAVersion | undefined> {
  try {
    const { version } = await fetchLatestWaWebVersion({
      signal: AbortSignal.timeout(VERSION_FETCH_TIMEOUT_MS),
    });
    lastKnownVersion = version;
  } catch (error) {
    logger.warn(
      { error: String(error), fallback: lastKnownVersion },
      'wa web version fetch failed'
    );
  }
  return lastKnownVersion;
}

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
    const version = await resolveWaVersion();
    const wantsPairingCode =
      usePairingCode ?? this.config.pairingMethod === 'code';

    const socket = makeWASocket({
      auth: state,
      agent,
      fetchAgent: agent,
      version,
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
      this.lastDisconnectReason =
        statusCode === DisconnectReason.loggedOut
          ? 'logged_out'
          : `code_${statusCode ?? 'unknown'}`;

      if (statusCode !== undefined && FATAL_CLOSE_CODES.has(statusCode)) {
        // stopped: impede que um timer de backoff já agendado ressuscite a
        // sessão morta. connect() zera isso, então o painel segue no controle.
        this.stopped = true;
        // Antes de apagar: o socket morto ainda pode emitir creds.update e
        // reescrever creds.json em cima do diretório que acabamos de remover.
        await this.teardownSocket();
        removeAuthState(this.config.id);
        this.jid = null;
        this.setStatus('disconnected');
        logger.warn(
          { id: this.config.id, statusCode },
          'fatal close — auth state wiped, waiting for a new pairing'
        );
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

  // lid → PN: contas migradas chegam endereçadas por @lid. remoteJidAlt traz o
  // PN; senão, o mapeamento que a própria lib persiste ao receber mensagens.
  // Grupo/broadcast → null (v1 é só chat direto).
  private async resolveUserJid(
    jid?: string | null,
    alt?: string | null
  ): Promise<string | null> {
    if (!jid) return null;
    if (isDirectUserJid(jid)) return jid;
    if (!jid.endsWith('@lid')) return null;
    if (alt && isDirectUserJid(alt)) return alt;
    const mapped = await this.socket?.signalRepository.lidMapping
      .getPNForLID(jid)
      .catch(() => null);
    return mapped && isDirectUserJid(mapped) ? mapped : null;
  }

  private async handleIncoming(message: WAMessage): Promise<void> {
    try {
      if (message.key.fromMe) return;
      // v1: direct user chats only — no groups, no status broadcast, no self.
      const rawJid = message.key.remoteJid;
      const jid = await this.resolveUserJid(rawJid, message.key.remoteJidAlt);
      if (!jid) {
        if (rawJid?.endsWith('@lid')) {
          logger.warn(
            { id: this.config.id, jid: rawJid, msgId: message.key.id },
            'inbound dropped: lid without resolvable PN'
          );
        } else {
          logger.info(
            { id: this.config.id, jid: rawJid },
            'inbound dropped: non-direct jid'
          );
        }
        return;
      }
      if (!message.message || !message.key.id) return;

      const media = await this.downloadMedia(message);
      const content = translateMessageContent(message.message, media);
      if (!content) {
        logger.info(
          {
            id: this.config.id,
            msgId: message.key.id,
            keys: Object.keys(message.message),
          },
          'inbound dropped: untranslatable content'
        );
        return;
      }

      const cloudMessage: CloudMessage = {
        from: jidToNumber(jid),
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
          jidToNumber(jid),
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
    const statuses: Array<{ id: string; status: string; recipientId: string }> = [];
    for (const item of updates) {
      if (!item.key.fromMe || !item.key.id) continue;
      const jid = await this.resolveUserJid(item.key.remoteJid, item.key.remoteJidAlt);
      if (!jid) {
        logger.info(
          { id: this.config.id, jid: item.key.remoteJid },
          'status dropped: unresolvable jid'
        );
        continue;
      }
      const status = translateStatus(item.update.status as number | undefined);
      if (!status) {
        logger.info(
          { id: this.config.id, msgId: item.key.id, rawStatus: item.update.status },
          'status dropped: unmapped status'
        );
        continue;
      }
      statuses.push({
        id: prefixedId(this.config.id, item.key.id),
        status,
        recipientId: jidToNumber(jid),
      });
    }

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
      this.socket.ev.removeAllListeners('creds.update');
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
