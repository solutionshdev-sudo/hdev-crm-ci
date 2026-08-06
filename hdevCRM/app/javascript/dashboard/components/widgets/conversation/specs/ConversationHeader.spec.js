import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { useRoute } from 'vue-router';
import ConversationHeader from '../ConversationHeader.vue';

vi.mock('vue-router');

const buildStore = currentChat =>
  createStore({
    getters: {
      getSelectedChat: () => currentChat,
      getCurrentAccountId: () => 1,
    },
    modules: {
      contacts: {
        namespaced: true,
        getters: {
          getContact: () => () => ({ name: 'Jane Doe', thumbnail: '' }),
        },
      },
      inboxes: {
        namespaced: true,
        getters: {
          getInbox: () => () => ({}),
          getInboxes: () => [],
          getInboxById: () => () => ({}),
        },
      },
    },
  });

const baseChat = {
  id: 1,
  meta: { sender: { id: 1 } },
  applied_sla: null,
};

const mountComponent = aiHandling => {
  const chat = { ...baseChat, ai_handling: aiHandling };
  return shallowMount(ConversationHeader, {
    props: { chat },
    global: {
      plugins: [buildStore(chat)],
      stubs: {
        'fluent-icon': true,
      },
    },
  });
};

describe('ConversationHeader', () => {
  beforeEach(() => {
    useRoute.mockReturnValue({ params: {}, name: 'inbox_conversation' });
  });

  it('shows the AI handling badge when ai_handling is true', () => {
    const wrapper = mountComponent(true);

    expect(wrapper.findComponent({ name: 'AiHandlingBadge' }).exists()).toBe(
      true
    );
  });

  it('does not show the AI handling badge when ai_handling is false', () => {
    const wrapper = mountComponent(false);

    expect(wrapper.findComponent({ name: 'AiHandlingBadge' }).exists()).toBe(
      false
    );
  });

  it('does not show the AI handling badge when ai_handling is undefined', () => {
    const wrapper = mountComponent(undefined);

    expect(wrapper.findComponent({ name: 'AiHandlingBadge' }).exists()).toBe(
      false
    );
  });
});
