import {
  isBaileysInbox,
  baileysStatus,
  isBaileysConnected,
  baileysStatusLabelKey,
  baileysStatusClass,
} from '../baileys';

const baileysInbox = {
  channel_type: 'Channel::Whatsapp',
  provider: 'baileys',
  connection_state: 'connected',
};

describe('#isBaileysInbox', () => {
  it('matches only whatsapp inboxes on the baileys provider', () => {
    expect(isBaileysInbox(baileysInbox)).toBe(true);
    expect(
      isBaileysInbox({ ...baileysInbox, provider: 'whatsapp_cloud' })
    ).toBe(false);
    expect(
      isBaileysInbox({ ...baileysInbox, channel_type: 'Channel::Api' })
    ).toBe(false);
    expect(isBaileysInbox(undefined)).toBe(false);
  });
});

describe('#baileysStatus', () => {
  it('falls back to disconnected when the state is unknown', () => {
    expect(baileysStatus(baileysInbox)).toBe('connected');
    expect(baileysStatus({})).toBe('disconnected');
  });
});

describe('#isBaileysConnected', () => {
  it('is true only while the session is open', () => {
    expect(isBaileysConnected(baileysInbox)).toBe(true);
    expect(
      isBaileysConnected({ ...baileysInbox, connection_state: 'connecting' })
    ).toBe(false);
  });
});

describe('#baileysStatusLabelKey', () => {
  it('builds the session status i18n key', () => {
    expect(baileysStatusLabelKey('qr')).toBe(
      'INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.STATUS.QR'
    );
    expect(baileysStatusLabelKey()).toBe(
      'INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.STATUS.DISCONNECTED'
    );
  });
});

describe('#baileysStatusClass', () => {
  it('uses teal when connected, amber while pairing and ruby otherwise', () => {
    expect(baileysStatusClass('connected')).toContain('teal');
    expect(baileysStatusClass('pairing')).toContain('amber');
    expect(baileysStatusClass('error')).toContain('ruby');
  });
});
