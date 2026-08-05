/* global axios */

import ApiClient from './ApiClient';

class CopilotAPI extends ApiClient {
  constructor() {
    super('copilot', { accountScoped: true });
  }

  // Roda o modelo com as ferramentas em preview: nada é gravado no banco.
  propose(messages) {
    return axios.post(this.url, { messages });
  }

  apply(changes) {
    return axios.post(`${this.url}/apply`, { changes });
  }
}

export default new CopilotAPI();
