import { shallowMount } from '@vue/test-utils';
import { useRouter, useRoute } from 'vue-router';
import ConversationCard from '../ConversationCard.vue';

vi.mock('vue-router');

const defaultConversation = {
  id: 1,
  priority: null,
  labels: [],
  timestamp: 1700000000,
};

const mountComponent = (conversation = {}) =>
  shallowMount(ConversationCard, {
    props: {
      conversation: { ...defaultConversation, ...conversation },
      contact: { name: 'Jane Doe' },
      stateInbox: { channelType: 'Channel::Api', medium: undefined },
      accountLabels: [],
    },
  });

describe('ConversationCard', () => {
  beforeEach(() => {
    useRouter.mockReturnValue({ push: vi.fn() });
    useRoute.mockReturnValue({ params: { accountId: 1 } });
  });

  it('shows the AI handling badge when ai_handling is true', () => {
    const wrapper = mountComponent({ ai_handling: true });

    expect(wrapper.findComponent({ name: 'AiHandlingBadge' }).exists()).toBe(
      true
    );
  });

  it('does not show the AI handling badge when ai_handling is false', () => {
    const wrapper = mountComponent({ ai_handling: false });

    expect(wrapper.findComponent({ name: 'AiHandlingBadge' }).exists()).toBe(
      false
    );
  });

  it('does not show the AI handling badge when ai_handling is undefined', () => {
    const wrapper = mountComponent({});

    expect(wrapper.findComponent({ name: 'AiHandlingBadge' }).exists()).toBe(
      false
    );
  });
});
