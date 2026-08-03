import { mount } from '@vue/test-utils';
import DealLostReasonModal from '../DealLostReasonModal.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const mountModal = (reasons = []) =>
  mount(DealLostReasonModal, { props: { reasons } });

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
});
