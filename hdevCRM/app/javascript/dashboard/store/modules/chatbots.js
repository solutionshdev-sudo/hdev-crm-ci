import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import ChatbotsAPI from '../../api/chatbots';
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
  getChatbots($state) {
    return $state.records;
  },
  getChatbot: $state => id => {
    return $state.records.find(record => record.id === Number(id));
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_CHATBOTS_UI_FLAG, { isFetching: true });
    try {
      const response = await ChatbotsAPI.get();
      commit(types.SET_CHATBOTS, response.data.payload);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_CHATBOTS_UI_FLAG, { isFetching: false });
    }
  },
  show: async ({ commit }, id) => {
    const response = await ChatbotsAPI.show(id);
    commit(types.ADD_CHATBOT, response.data);
    return response.data;
  },
  create: async ({ commit }, chatbotObj) => {
    commit(types.SET_CHATBOTS_UI_FLAG, { isCreating: true });
    try {
      const response = await ChatbotsAPI.create(chatbotObj);
      commit(types.ADD_CHATBOT, response.data);
      return response.data;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.SET_CHATBOTS_UI_FLAG, { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...chatbotObj }) => {
    commit(types.SET_CHATBOTS_UI_FLAG, { isUpdating: true });
    try {
      const response = await ChatbotsAPI.update(id, chatbotObj);
      commit(types.EDIT_CHATBOT, response.data);
      return response.data;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.SET_CHATBOTS_UI_FLAG, { isUpdating: false });
    }
  },
  clone: async ({ commit }, id) => {
    const response = await ChatbotsAPI.clone(id);
    commit(types.ADD_CHATBOT, response.data);
    return response.data;
  },
  toggle: async ({ commit }, id) => {
    const response = await ChatbotsAPI.toggle(id);
    commit(types.EDIT_CHATBOT, response.data);
    return response.data;
  },
  delete: async ({ commit }, id) => {
    commit(types.SET_CHATBOTS_UI_FLAG, { isDeleting: true });
    try {
      await ChatbotsAPI.delete(id);
      commit(types.DELETE_CHATBOT, id);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_CHATBOTS_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_CHATBOTS_UI_FLAG]($state, data) {
    $state.uiFlags = { ...$state.uiFlags, ...data };
  },
  [types.SET_CHATBOTS]: MutationHelpers.set,
  [types.ADD_CHATBOT]: MutationHelpers.setSingleRecord,
  [types.EDIT_CHATBOT]: MutationHelpers.update,
  [types.DELETE_CHATBOT]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
