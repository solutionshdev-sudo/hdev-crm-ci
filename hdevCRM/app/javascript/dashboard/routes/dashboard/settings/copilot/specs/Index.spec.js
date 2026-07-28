import { mount, flushPromises } from '@vue/test-utils';
import Index from '../Index.vue';
import CopilotAPI from 'dashboard/api/copilot';

vi.mock('dashboard/api/copilot', () => ({
  default: { propose: vi.fn(), apply: vi.fn() },
}));

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const mountCopilot = () =>
  mount(Index, {
    global: {
      stubs: { MessageList: true },
    },
  });

const propose = async (wrapper, text = 'cria um funil') => {
  await wrapper.find('[data-test-id="copilot-input"]').setValue(text);
  await wrapper.find('[data-test-id="copilot-propose"]').trigger('click');
  await flushPromises();
};

describe('Copilot Index', () => {
  it('lists the result of each proposed change without applying anything', async () => {
    CopilotAPI.propose.mockResolvedValue({
      data: {
        reply: 'Confirma?',
        changes: [
          { name: 'create_deal_pipeline', input: {}, result: 'Funil "Vendas".' },
          { name: 'create_labels', input: {}, result: 'Etiquetas: novo.' },
        ],
      },
    });

    const wrapper = mountCopilot();
    await propose(wrapper);

    const changes = wrapper.findAll('[data-test-id="copilot-change"]');
    expect(changes.map(change => change.text())).toEqual([
      'Funil "Vendas".',
      'Etiquetas: novo.',
    ]);
    expect(CopilotAPI.apply).not.toHaveBeenCalled();
  });

  it('sends the raw change array on apply and clears the preview', async () => {
    const changes = [
      { name: 'create_deal_pipeline', input: { name: 'Vendas' }, result: 'ok' },
    ];
    CopilotAPI.propose.mockResolvedValue({ data: { reply: '', changes } });
    CopilotAPI.apply.mockResolvedValue({ data: { results: ['ok'] } });

    const wrapper = mountCopilot();
    await propose(wrapper);
    await wrapper.find('[data-test-id="copilot-apply"]').trigger('click');
    await flushPromises();

    expect(CopilotAPI.apply).toHaveBeenCalledWith(changes);
    expect(wrapper.find('[data-test-id="copilot-change"]').exists()).toBe(false);
  });
});
