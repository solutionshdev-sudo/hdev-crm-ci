/* global axios */

import ApiClient from './ApiClient';

class AiAgentAPI extends ApiClient {
  constructor() {
    super('ai_agent', { accountScoped: true });
  }

  getConfig() {
    return axios.get(this.url);
  }

  updateConfig(config) {
    return axios.patch(this.url, config);
  }

  getUsage() {
    return axios.get(`${this.baseUrl()}/ai_usage`);
  }
}

export default new AiAgentAPI();
