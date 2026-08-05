/* global axios */
import ApiClient from '../ApiClient';

// Sessão do WhatsApp não-oficial (baileys-service), rotas member da inbox.
class BaileysAPI extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  getStatus(inboxId) {
    return axios.get(`${this.url}/${inboxId}/baileys_status`);
  }

  connect(inboxId, { usePairingCode = false } = {}) {
    return axios.post(`${this.url}/${inboxId}/baileys_connect`, {
      use_pairing_code: usePairingCode || undefined,
    });
  }

  logout(inboxId) {
    return axios.post(`${this.url}/${inboxId}/baileys_logout`);
  }
}

export default new BaileysAPI();
