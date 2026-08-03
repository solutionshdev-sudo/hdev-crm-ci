import { computed } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import Index from '../Index.vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

vi.mock('dashboard/composables/store');
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const stage = {
  id: 1,
  name: 'Novo Lead',
  color: '#64748B',
  probability: 10,
  stage_type: 'open',
};

const pipelineWithoutVocabulary = {
  id: 10,
  name: 'Funil',
  description: '',
  stages: [stage],
  vocabulary: {},
};

const pipelineWithVocabulary = {
  id: 11,
  name: 'Funil customizado',
  description: '',
  stages: [stage],
  vocabulary: {
    lead: 'Prospect',
    deal: 'Oportunidade',
    won: 'Fechado',
    lost: 'Cancelado',
  },
};

const mountIndex = () =>
  mount(Index, {
    global: {
      // BaseSettingsHeader puxa a policy de marca branca via getters do Vuex
      // real; fora de escopo aqui — só interessa o comportamento do
      // vocabulário no formulário de edição.
      stubs: { BaseSettingsHeader: true },
    },
  });

describe('DealPipelines Index', () => {
  let dispatch;

  beforeEach(() => {
    dispatch = vi.fn().mockResolvedValue({});
    useStore.mockReturnValue({ dispatch });
    useAlert.mockReturnValue(vi.fn());
  });

  const setupPipelines = pipelines => {
    useMapGetter.mockImplementation(getter => {
      const map = { 'dealPipelines/getPipelines': pipelines };
      return computed(() => map[getter]);
    });
  };

  describe('vocabulário do funil', () => {
    it('pre-fills the vocabulary fields with the product defaults when the pipeline has none', async () => {
      setupPipelines([pipelineWithoutVocabulary]);
      const wrapper = mountIndex();
      await flushPromises();

      await wrapper.find('[data-test-id="edit-pipeline"]').trigger('click');
      await flushPromises();

      expect(
        wrapper.find('[data-test-id="vocabulary-lead"]').element.value
      ).toBe('Lead');
      expect(
        wrapper.find('[data-test-id="vocabulary-deal"]').element.value
      ).toBe('Negócio');
      expect(
        wrapper.find('[data-test-id="vocabulary-won"]').element.value
      ).toBe('Ganho');
      expect(
        wrapper.find('[data-test-id="vocabulary-lost"]').element.value
      ).toBe('Perdido');
    });

    it('pre-fills the vocabulary fields with the pipeline current vocabulary when set', async () => {
      setupPipelines([pipelineWithVocabulary]);
      const wrapper = mountIndex();
      await flushPromises();

      await wrapper.find('[data-test-id="edit-pipeline"]').trigger('click');
      await flushPromises();

      expect(
        wrapper.find('[data-test-id="vocabulary-lead"]').element.value
      ).toBe('Prospect');
      expect(
        wrapper.find('[data-test-id="vocabulary-deal"]').element.value
      ).toBe('Oportunidade');
      expect(
        wrapper.find('[data-test-id="vocabulary-won"]').element.value
      ).toBe('Fechado');
      expect(
        wrapper.find('[data-test-id="vocabulary-lost"]').element.value
      ).toBe('Cancelado');
    });

    it('sends the edited vocabulary in the update dispatch on save', async () => {
      setupPipelines([pipelineWithoutVocabulary]);
      const wrapper = mountIndex();
      await flushPromises();

      await wrapper.find('[data-test-id="edit-pipeline"]').trigger('click');
      await flushPromises();

      await wrapper
        .find('[data-test-id="vocabulary-lost"]')
        .setValue('Cancelado');
      await wrapper.find('[data-test-id="save-pipeline"]').trigger('click');
      await flushPromises();

      expect(dispatch).toHaveBeenCalledWith(
        'dealPipelines/update',
        expect.objectContaining({
          id: 10,
          vocabulary: expect.objectContaining({
            lead: 'Lead',
            deal: 'Negócio',
            won: 'Ganho',
            lost: 'Cancelado',
          }),
        })
      );
    });
  });
});
