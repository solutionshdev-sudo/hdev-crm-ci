import { mount } from '@vue/test-utils';
import DealLostReasonModal from '../DealLostReasonModal.vue';

// As duas chaves de título têm texto real aqui (não o eco da chave) porque o
// teste de vocabulário precisa conferir a palavra customizada de fato
// interpolada no título renderizado, não só qual chave foi chamada.
const TITLE_TEMPLATES = {
  'DEALS.LOST_REASON.TITLE': 'Why was this deal lost?',
  'DEALS.LOST_REASON.TITLE_VOCAB': 'Why was this marked as {lost}?',
};

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => {
      const template = TITLE_TEMPLATES[key] || key;
      if (!params) return template;
      return Object.entries(params).reduce(
        (acc, [name, value]) => acc.replace(`{${name}}`, value),
        template
      );
    },
  }),
}));

const mountModal = (reasons = [], lostLabel = '') =>
  mount(DealLostReasonModal, {
    props: { reasons, lostLabel },
    global: {
      // O stub global de WootModalHeader (vitest.setup.js) só renderiza o
      // slot e ignora a prop header-title; aqui ela precisa aparecer de
      // verdade pra conferir o texto do título.
      stubs: {
        WootModalHeader: {
          props: ['headerTitle'],
          template: '<div>{{ headerTitle }}</div>',
        },
      },
    },
  });

describe('DealLostReasonModal', () => {
  it('shows a free text field when the account has no configured reasons', () => {
    const wrapper = mountModal([]);

    expect(wrapper.find('[data-test-id="lost-reason-select"]').exists()).toBe(
      false
    );
    expect(wrapper.find('[data-test-id="lost-reason-input"]').exists()).toBe(
      true
    );
  });

  it('shows a select with the configured reasons plus an "other" option', () => {
    const wrapper = mountModal(['Preço', 'Concorrência']);

    const options = wrapper.findAll(
      '[data-test-id="lost-reason-select"] option'
    );
    const values = options.map(option => option.element.value);
    expect(values).toEqual(
      expect.arrayContaining(['Preço', 'Concorrência', '__other__'])
    );
    expect(wrapper.find('[data-test-id="lost-reason-input"]').exists()).toBe(
      false
    );
  });

  it('reveals the free text field when "other" is selected', async () => {
    const wrapper = mountModal(['Preço']);

    await wrapper
      .find('[data-test-id="lost-reason-select"]')
      .setValue('__other__');

    expect(wrapper.find('[data-test-id="lost-reason-input"]').exists()).toBe(
      true
    );
  });

  it('emits confirm with the selected reason', async () => {
    const wrapper = mountModal(['Preço', 'Concorrência']);

    await wrapper
      .find('[data-test-id="lost-reason-select"]')
      .setValue('Concorrência');
    await wrapper.find('[data-test-id="lost-reason-confirm"]').trigger('click');

    expect(wrapper.emitted('confirm')).toEqual([['Concorrência']]);
  });

  it('emits confirm with the typed reason when there are no configured reasons', async () => {
    const wrapper = mountModal([]);

    await wrapper
      .find('[data-test-id="lost-reason-input"]')
      .setValue('Cliente desistiu');
    await wrapper.find('[data-test-id="lost-reason-confirm"]').trigger('click');

    expect(wrapper.emitted('confirm')).toEqual([['Cliente desistiu']]);
  });

  it('does not emit confirm when the reason is blank', async () => {
    const wrapper = mountModal([]);

    await wrapper.find('[data-test-id="lost-reason-confirm"]').trigger('click');

    expect(wrapper.emitted('confirm')).toBeUndefined();
  });

  it('emits cancel', async () => {
    const wrapper = mountModal([]);

    await wrapper.find('[data-test-id="lost-reason-cancel"]').trigger('click');

    expect(wrapper.emitted('cancel')).toHaveLength(1);
  });

  describe('vocabulary-aware title', () => {
    it('shows the fixed title when the pipeline has no custom lost label', () => {
      const wrapper = mountModal([], '');

      expect(wrapper.text()).toContain('Why was this deal lost?');
    });

    it('shows the title with the custom lost label when the pipeline sets one', () => {
      const wrapper = mountModal([], 'Cancelado');

      expect(wrapper.text()).toContain('Why was this marked as Cancelado?');
    });
  });
});
