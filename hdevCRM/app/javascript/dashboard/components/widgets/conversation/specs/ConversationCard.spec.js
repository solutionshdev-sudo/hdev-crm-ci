import { shallowMount } from '@vue/test-utils';
import ConversationCard from '../ConversationCard.vue';

const defaultChat = {
  id: 1,
  labels: [],
  messages: [],
  priority: null,
  unread_count: 0,
  timestamp: 1700000000,
  created_at: 1700000000,
};

// Shallow stubs don't render named slots by default, so `CardLabels` is
// replaced with a passthrough that keeps the `#before` slot (where the AI
// badge lives) visible to `findComponent`.
const CardLabelsStub = {
  name: 'CardLabels',
  template: '<div><slot name="before" /><slot /></div>',
};

const mountComponent = (chat, currentContact = {}) =>
  shallowMount(ConversationCard, {
    props: {
      chat: { ...defaultChat, ...chat },
      currentContact: {
        name: 'Jane Doe',
        thumbnail: '',
        availability_status: 'offline',
        ...currentContact,
      },
      inbox: { id: 1 },
    },
    global: {
      stubs: {
        'fluent-icon': true,
        CardLabels: CardLabelsStub,
      },
    },
  });

describe('ConversationCard', () => {
  it('does not reserve the labels row when only a persisted SLA policy id is present', () => {
    const wrapper = mountComponent({ sla_policy_id: 1, applied_sla: null });

    expect(wrapper.findComponent({ name: 'CardLabels' }).exists()).toBe(false);
  });

  it('shows the labels row when an active applied SLA is present', () => {
    const wrapper = mountComponent({
      sla_policy_id: 1,
      applied_sla: { id: 1 },
    });

    expect(wrapper.findComponent({ name: 'CardLabels' }).exists()).toBe(true);
  });

  it('does not reserve the labels row when the contact is blocked', () => {
    const wrapper = mountComponent(
      {
        sla_policy_id: 1,
        applied_sla: { id: 1 },
      },
      { blocked: true }
    );

    expect(wrapper.findComponent({ name: 'CardLabels' }).exists()).toBe(false);
  });

  it('shows the AI handling badge when ai_handling is true', () => {
    const wrapper = mountComponent({ ai_handling: true });

    expect(wrapper.findComponent({ name: 'CardLabels' }).exists()).toBe(true);
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
