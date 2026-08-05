import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import DealsAPI from '../../api/deals';
import { throwErrorMessage } from '../utils/api';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
    isMoving: false,
  },
};

export const getters = {
  getDeals($state) {
    return $state.records;
  },
  getDeal: $state => id => {
    return $state.records.find(record => record.id === Number(id));
  },
  getDealsByStage: $state => stageId => {
    return $state.records
      .filter(record => record.deal_stage_id === Number(stageId))
      .sort((a, b) => Number(a.position) - Number(b.position));
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  get: async ({ commit }, params = {}) => {
    commit(types.SET_DEALS_UI_FLAG, { isFetching: true });
    try {
      const response = await DealsAPI.get(params);
      commit(types.SET_DEALS, response.data.payload);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isFetching: false });
    }
  },
  create: async ({ commit }, dealObj) => {
    commit(types.SET_DEALS_UI_FLAG, { isCreating: true });
    try {
      const response = await DealsAPI.create({ deal: dealObj });
      commit(types.ADD_DEAL, response.data);
      return response.data;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...dealObj }) => {
    commit(types.SET_DEALS_UI_FLAG, { isUpdating: true });
    try {
      const response = await DealsAPI.update(id, { deal: dealObj });
      commit(types.EDIT_DEAL, response.data);
      return response.data;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isUpdating: false });
    }
  },
  move: async ({ commit }, { id, stageId, beforeDealId, afterDealId }) => {
    commit(types.SET_DEALS_UI_FLAG, { isMoving: true });
    try {
      const response = await DealsAPI.move(id, {
        stageId,
        beforeDealId,
        afterDealId,
      });
      commit(types.EDIT_DEAL, response.data);
      return response.data;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isMoving: false });
    }
  },
  delete: async ({ commit }, id) => {
    commit(types.SET_DEALS_UI_FLAG, { isDeleting: true });
    try {
      await DealsAPI.delete(id);
      commit(types.DELETE_DEAL, id);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_DEALS_UI_FLAG]($state, data) {
    $state.uiFlags = { ...$state.uiFlags, ...data };
  },
  [types.SET_DEALS]: MutationHelpers.set,
  [types.ADD_DEAL]: MutationHelpers.setSingleRecord,
  [types.EDIT_DEAL]: MutationHelpers.update,
  [types.DELETE_DEAL]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
