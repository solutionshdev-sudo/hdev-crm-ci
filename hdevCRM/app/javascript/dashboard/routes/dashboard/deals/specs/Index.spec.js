import { computed } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import Index from '../Index.vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';

vi.mock('dashboard/composables/store');
vi.mock('dashboard/composables/useAccount');
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const openStage = { id: 1, name: 'Aberto', stage_type: 'open', color: '#000' };
const lostStage = { id: 2, name: 'Perdido', stage_type: 'lost', color: '#000' };
const pipeline = {
  id: 10,
  name: 'Funil',
  stages: [openStage, lostStage],
  vocabulary: {},
};
const pipelineWithVocabulary = {
  id: 11,
  name: 'Funil com vocabulário',
  stages: [openStage, lostStage],
  vocabulary: { deal: 'Oportunidade', lost: 'Cancelado' },
};

// Stub minúsculo do DealColumn: expõe um botão por coluna que dispara o
// evento `move` do jeito que o vuedraggable dispararia (o drag em si já foi
// exercitado nos testes reais do drag-and-drop; aqui só interessa o que o
// Index.vue faz com o evento).
const DealColumnStub = {
  props: ['stage', 'deals'],
  emits: ['move', 'openDeal'],
  template: `<button :data-test-id="'move-to-' + stage.id" @click="$emit('move', { dealId: 1, stageId: stage.id, beforeDealId: null, afterDealId: null })" />`,
};

const mountIndex = () =>
  mount(Index, {
    global: {
      stubs: {
        DealColumn: DealColumnStub,
        DealForm: true,
        DealActivityFeed: true,
      },
    },
  });

describe('Deals Index', () => {
  let dispatch;

  beforeEach(() => {
    dispatch = vi.fn().mockResolvedValue({});
    useStore.mockReturnValue({ dispatch });
    useMapGetter.mockImplementation(getter => {
      const map = {
        'dealPipelines/getPipelines': [pipeline],
        'deals/getDealsByStage': () => [],
      };
      return computed(() => map[getter]);
    });
    useAccount.mockReturnValue({
      currentAccount: { value: { settings: { deal_lost_reasons: [] } } },
    });
    useAlert.mockReturnValue(vi.fn());
  });

  it('moves the deal directly when the target stage is not a lost stage', async () => {
    const wrapper = mountIndex();
    await flushPromises();

    await wrapper.find('[data-test-id="move-to-1"]').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('deals/move', {
      id: 1,
      stageId: 1,
      beforeDealId: null,
      afterDealId: null,
    });
    expect(
      wrapper.findComponent({ name: 'DealLostReasonModal' }).exists()
    ).toBe(false);
  });

  it('opens the lost reason modal instead of persisting when the target stage is a lost stage', async () => {
    const wrapper = mountIndex();
    await flushPromises();

    await wrapper.find('[data-test-id="move-to-2"]').trigger('click');
    await flushPromises();

    expect(dispatch).not.toHaveBeenCalledWith('deals/move', expect.anything());
    expect(
      wrapper.findComponent({ name: 'DealLostReasonModal' }).exists()
    ).toBe(true);
  });

  it('persists deal_stage_id and lost_reason when the modal is confirmed', async () => {
    const wrapper = mountIndex();
    await flushPromises();

    await wrapper.find('[data-test-id="move-to-2"]').trigger('click');
    await flushPromises();

    const modal = wrapper.findComponent({ name: 'DealLostReasonModal' });
    modal.vm.$emit('confirm', 'Preço muito alto');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('deals/update', {
      id: 1,
      deal_stage_id: 2,
      lost_reason: 'Preço muito alto',
    });
  });

  it('does not persist anything when the modal is cancelled', async () => {
    const wrapper = mountIndex();
    await flushPromises();

    await wrapper.find('[data-test-id="move-to-2"]').trigger('click');
    await flushPromises();

    const modal = wrapper.findComponent({ name: 'DealLostReasonModal' });
    modal.vm.$emit('cancel');
    await flushPromises();

    expect(dispatch).not.toHaveBeenCalledWith(
      'deals/update',
      expect.anything()
    );
    expect(dispatch).not.toHaveBeenCalledWith('deals/move', expect.anything());
    expect(
      wrapper.findComponent({ name: 'DealLostReasonModal' }).exists()
    ).toBe(false);
  });

  describe('vocabulary do funil selecionado', () => {
    it('shows the fallback I18n title when the pipeline has no custom vocabulary', async () => {
      const wrapper = mountIndex();
      await flushPromises();

      expect(wrapper.find('h1').text()).toBe('DEALS.BOARD.TITLE');
    });

    it('shows the vocabulary label as the board title when the pipeline sets one', async () => {
      useMapGetter.mockImplementation(getter => {
        const map = {
          'dealPipelines/getPipelines': [pipelineWithVocabulary],
          'deals/getDealsByStage': () => [],
        };
        return computed(() => map[getter]);
      });

      const wrapper = mountIndex();
      await flushPromises();

      expect(wrapper.find('h1').text()).toBe('Oportunidade');
    });

    it('passes the fallback (empty) lost label to the modal when the pipeline has no custom vocabulary', async () => {
      const wrapper = mountIndex();
      await flushPromises();

      await wrapper.find('[data-test-id="move-to-2"]').trigger('click');
      await flushPromises();

      const modal = wrapper.findComponent({ name: 'DealLostReasonModal' });
      expect(modal.props('lostLabel')).toBe('');
    });

    it('passes the vocabulary lost label to the modal when the pipeline sets one', async () => {
      useMapGetter.mockImplementation(getter => {
        const map = {
          'dealPipelines/getPipelines': [pipelineWithVocabulary],
          'deals/getDealsByStage': () => [],
        };
        return computed(() => map[getter]);
      });

      const wrapper = mountIndex();
      await flushPromises();

      await wrapper.find('[data-test-id="move-to-2"]').trigger('click');
      await flushPromises();

      const modal = wrapper.findComponent({ name: 'DealLostReasonModal' });
      expect(modal.props('lostLabel')).toBe('Cancelado');
    });
  });
});
