/* global axios */
import ApiClient from './ApiClient';

class DealsAPI extends ApiClient {
  constructor() {
    super('deals', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  move(dealId, { stageId, beforeDealId, afterDealId }) {
    return axios.post(`${this.url}/${dealId}/move`, {
      stage_id: stageId,
      before_deal_id: beforeDealId,
      after_deal_id: afterDealId,
    });
  }

  getActivities(dealId) {
    return axios.get(`${this.url}/${dealId}/activities`);
  }
}

export default new DealsAPI();
