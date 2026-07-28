import { INBOX_TYPES } from './inbox';

export const BAILEYS_PROVIDER = 'baileys';

// Estados vindos do microserviço. 'error' é sintético do painel: o serviço não
// respondeu ao polling.
export const BAILEYS_TRANSIENT_STATES = ['connecting', 'qr', 'pairing'];

// O Rails devolve isso em lastError quando o microserviço não conhece a
// instância — a sessão está parada, basta gerar um QR novo.
export const BAILEYS_NOT_PROVISIONED = 'not_provisioned';

const STATUS_CLASSES = {
  connected: 'bg-n-teal-3 text-n-teal-11',
  connecting: 'bg-n-amber-3 text-n-amber-11',
  qr: 'bg-n-amber-3 text-n-amber-11',
  pairing: 'bg-n-amber-3 text-n-amber-11',
};

const DEFAULT_STATUS = 'disconnected';

export const isBaileysInbox = inbox =>
  inbox?.channel_type === INBOX_TYPES.WHATSAPP &&
  inbox?.provider === BAILEYS_PROVIDER;

export const baileysStatus = inbox => inbox?.connection_state || DEFAULT_STATUS;

export const isBaileysConnected = inbox => baileysStatus(inbox) === 'connected';

export const baileysStatusLabelKey = (status = DEFAULT_STATUS) =>
  `INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.STATUS.${(
    status || DEFAULT_STATUS
  ).toUpperCase()}`;

export const baileysStatusClass = (status = DEFAULT_STATUS) =>
  STATUS_CLASSES[status] || 'bg-n-ruby-3 text-n-ruby-11';
