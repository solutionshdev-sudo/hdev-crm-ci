/* global axios */
import ApiClient from './ApiClient';

class ChatbotsAPI extends ApiClient {
  constructor() {
    super('chatbots', { accountScoped: true });
  }

  clone(chatbotId) {
    return axios.post(`${this.url}/${chatbotId}/clone`);
  }

  toggle(chatbotId) {
    return axios.post(`${this.url}/${chatbotId}/toggle`);
  }

  getSessions(chatbotId) {
    return axios.get(`${this.url}/${chatbotId}/sessions`);
  }
}

export default new ChatbotsAPI();
