/* global axios */
import ApiClient from './ApiClient';

class DealPipelinesAPI extends ApiClient {
  constructor() {
    super('deal_pipelines', { accountScoped: true });
  }

  reorderStages(pipelineId, stageIds) {
    return axios.post(`${this.url}/${pipelineId}/reorder_stages`, {
      stage_ids: stageIds,
    });
  }
}

export default new DealPipelinesAPI();
