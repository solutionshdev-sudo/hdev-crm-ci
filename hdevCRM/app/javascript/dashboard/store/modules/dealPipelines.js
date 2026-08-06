import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import DealPipelinesAPI from '../../api/dealPipelines';
import { throwErrorMessage } from '../utils/api';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getPipelines($state) {
    return $state.records;
  },
  getPipeline: $state => id => {
    return $state.records.find(record => record.id === Number(id));
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_DEAL_PIPELINES_UI_FLAG, { isFetching: true });
    try {
      const response = await DealPipelinesAPI.get();
      commit(types.SET_DEAL_PIPELINES, response.data.payload);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_DEAL_PIPELINES_UI_FLAG, { isFetching: false });
    }
  },
  create: async ({ commit }, pipelineObj) => {
    commit(types.SET_DEAL_PIPELINES_UI_FLAG, { isCreating: true });
    try {
      const response = await DealPipelinesAPI.create(pipelineObj);
      commit(types.ADD_DEAL_PIPELINE, response.data);
      return response.data;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.SET_DEAL_PIPELINES_UI_FLAG, { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...pipelineObj }) => {
    commit(types.SET_DEAL_PIPELINES_UI_FLAG, { isUpdating: true });
    try {
      const response = await DealPipelinesAPI.update(id, pipelineObj);
      commit(types.EDIT_DEAL_PIPELINE, response.data);
      return response.data;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.SET_DEAL_PIPELINES_UI_FLAG, { isUpdating: false });
    }
  },
  delete: async ({ commit }, id) => {
    commit(types.SET_DEAL_PIPELINES_UI_FLAG, { isDeleting: true });
    try {
      await DealPipelinesAPI.delete(id);
      commit(types.DELETE_DEAL_PIPELINE, id);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_DEAL_PIPELINES_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_DEAL_PIPELINES_UI_FLAG]($state, data) {
    $state.uiFlags = { ...$state.uiFlags, ...data };
  },
  [types.SET_DEAL_PIPELINES]: MutationHelpers.set,
  [types.ADD_DEAL_PIPELINE]: MutationHelpers.setSingleRecord,
  [types.EDIT_DEAL_PIPELINE]: MutationHelpers.update,
  [types.DELETE_DEAL_PIPELINE]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
