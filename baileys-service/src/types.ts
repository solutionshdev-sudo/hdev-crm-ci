export type InstanceStatus =
  | 'disconnected'
  | 'connecting'
  | 'qr'
  | 'pairing'
  | 'connected';

// Persisted next to the Baileys auth state so the instance survives restarts.
export interface InstanceConfig {
  id: string;
  phoneNumber: string;
  webhookUrl: string;
  webhookSecret: string;
  proxyUrl?: string | null;
  pairingMethod?: 'qr' | 'code';
}

export interface InstanceSnapshot {
  id: string;
  status: InstanceStatus;
  qr?: string | null;
  pairingCode?: string | null;
  jid?: string | null;
  phoneNumber: string;
  lastError?: string | null;
  lastDisconnectReason?: string | null;
}
