/* global axios */

import ApiClient from './ApiClient';

class AgenciesAPI extends ApiClient {
  constructor() {
    super('agencies', {});
  }

  list() {
    return axios.get(this.url);
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, data);
  }

  getAccounts(id) {
    return axios.get(`${this.url}/${id}/accounts`);
  }

  createAccount(id, data) {
    return axios.post(`${this.url}/${id}/accounts`, data);
  }

  getAiUsage(id) {
    return axios.get(`${this.url}/${id}/ai_usage`);
  }
}

export default new AgenciesAPI();
