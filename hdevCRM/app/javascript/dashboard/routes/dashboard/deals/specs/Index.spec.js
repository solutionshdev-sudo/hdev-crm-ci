import { computed } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import Index from '../Index.vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';

vi.mock('dashboard/composables/store');
vi.mock('dashboard/composables/useAccount');
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

// Chaves com template real de interpolação (mesma convenção do
// DealLostReasonModal.spec.js): só assim dá pra conferir o rótulo do
// vocabulário interpolado de fato, não só qual chave foi chamada.
const TEXT_TEMPLATES = {
  'DEALS.BOARD.NEW_DEAL': 'New deal',
  'DEALS.BOARD.NEW_WITH_LABEL': 'New {label}',
};
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => {
      const template = TEXT_TEMPLATES[key] || key;
      if (!params) return template;
      return Object.entries(params).reduce(
        (acc, [name, value]) => acc.replace(`{${name}}`, value),
        template
      );
    },
  }),
}));

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
// Index.vue faz com o evento) e um botão que abre o negócio pra edição
// (@open-deal), pra exercitar o form de edição sem montar o DealColumn real.
const DealColumnStub = {
  props: ['stage', 'deals'],
  emits: ['move', 'open-deal'],
  template: `
    <div>
      <button :data-test-id="'move-to-' + stage.id" @click="$emit('move', { dealId: 1, stageId: stage.id, beforeDealId: null, afterDealId: null })" />
      <button :data-test-id="'open-deal-in-' + stage.id" @click="$emit('open-deal', { id: 1, title: 'Negócio 1', deal_stage_id: stage.id, lost_reason: null })" />
    </div>
  `,
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
    // Decisão do controller (T3): o título do board é sempre o nome da
    // ferramenta ("Kanban"), não o vocabulário. O vocabulário.deal virou
    // rótulo de conteúdo — vive só no botão/modal de criação.
    it('shows the fixed board title when the pipeline has no custom vocabulary', async () => {
      const wrapper = mountIndex();
      await flushPromises();

      expect(wrapper.find('h1').text()).toBe('DEALS.BOARD.TITLE');
    });

    it('keeps the fixed board title even when the pipeline sets a custom vocabulary', async () => {
      useMapGetter.mockImplementation(getter => {
        const map = {
          'dealPipelines/getPipelines': [pipelineWithVocabulary],
          'deals/getDealsByStage': () => [],
        };
        return computed(() => map[getter]);
      });

      const wrapper = mountIndex();
      await flushPromises();

      expect(wrapper.find('h1').text()).toBe('DEALS.BOARD.TITLE');
    });

    // O NextButton é stub global (vitest.setup.js: `<button><slot/></button>`,
    // sem usar a prop `label`), então o valor cai como atributo HTML puro no
    // fallthrough do Vue — daí conferir o atributo, não o texto do botão.
    it('uses the plain "new deal" label on the button when the pipeline has no custom vocabulary', async () => {
      const wrapper = mountIndex();
      await flushPromises();

      expect(
        wrapper.find('[data-test-id="new-deal-button"]').attributes('label')
      ).toBe('New deal');
    });

    it('uses the interpolated vocabulary label on the button when the pipeline sets one', async () => {
      useMapGetter.mockImplementation(getter => {
        const map = {
          'dealPipelines/getPipelines': [pipelineWithVocabulary],
          'deals/getDealsByStage': () => [],
        };
        return computed(() => map[getter]);
      });

      const wrapper = mountIndex();
      await flushPromises();

      expect(
        wrapper.find('[data-test-id="new-deal-button"]').attributes('label')
      ).toBe('New Oportunidade');
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

  describe('editando um negócio pelo form (segundo caminho pra etapa perdida)', () => {
    // O WootModal global (vitest.setup.js) renderiza o slot sempre, mesmo
    // com show=false — então o DealForm de criação (sempre montado, sem
    // prop `deal`) e o de edição convivem no DOM. Distingue pela prop
    // `deal`, que só o form de edição recebe.
    const findEditForm = wrapper =>
      wrapper
        .findAllComponents({ name: 'DealForm' })
        .find(f => f.props('deal'));

    // Abre o form de edição do negócio 1 (via @open-deal do stub) e devolve
    // o wrapper já com o modal aberto.
    const openDealForEdit = async (wrapper, stageId = 1) => {
      await wrapper
        .find(`[data-test-id="open-deal-in-${stageId}"]`)
        .trigger('click');
      await flushPromises();
      return findEditForm(wrapper);
    };

    it('dispatches deals/update directly when editing to a non-lost stage', async () => {
      const wrapper = mountIndex();
      await flushPromises();

      const form = await openDealForEdit(wrapper);
      form.vm.$emit('submit', { title: 'Negócio 1', deal_stage_id: 1 });
      await flushPromises();

      expect(dispatch).toHaveBeenCalledWith('deals/update', {
        id: 1,
        title: 'Negócio 1',
        deal_stage_id: 1,
      });
      expect(
        wrapper.findComponent({ name: 'DealLostReasonModal' }).exists()
      ).toBe(false);
    });

    it('opens the lost reason modal instead of persisting when editing to a lost stage', async () => {
      const wrapper = mountIndex();
      await flushPromises();

      const form = await openDealForEdit(wrapper);
      form.vm.$emit('submit', { title: 'Negócio 1', deal_stage_id: 2 });
      await flushPromises();

      expect(dispatch).not.toHaveBeenCalledWith(
        'deals/update',
        expect.anything()
      );
      expect(
        wrapper.findComponent({ name: 'DealLostReasonModal' }).exists()
      ).toBe(true);
    });

    it('dispatches deals/update with the reason merged in when the modal is confirmed', async () => {
      const wrapper = mountIndex();
      await flushPromises();

      const form = await openDealForEdit(wrapper);
      form.vm.$emit('submit', {
        title: 'Negócio 1',
        value: 42,
        deal_stage_id: 2,
      });
      await flushPromises();

      const modal = wrapper.findComponent({ name: 'DealLostReasonModal' });
      modal.vm.$emit('confirm', 'Sem verba');
      await flushPromises();

      expect(dispatch).toHaveBeenCalledWith('deals/update', {
        id: 1,
        title: 'Negócio 1',
        value: 42,
        deal_stage_id: 2,
        lost_reason: 'Sem verba',
      });
    });

    it('does not persist and keeps the form open when the modal is cancelled', async () => {
      const wrapper = mountIndex();
      await flushPromises();

      const form = await openDealForEdit(wrapper);
      form.vm.$emit('submit', { title: 'Negócio 1', deal_stage_id: 2 });
      await flushPromises();

      const modal = wrapper.findComponent({ name: 'DealLostReasonModal' });
      modal.vm.$emit('cancel');
      await flushPromises();

      expect(dispatch).not.toHaveBeenCalledWith(
        'deals/update',
        expect.anything()
      );
      expect(
        wrapper.findComponent({ name: 'DealLostReasonModal' }).exists()
      ).toBe(false);
      // Form de edição segue aberto — nada foi persistido, o usuário decide
      // de novo (mudar a etapa ou cancelar de vez).
      expect(findEditForm(wrapper)).toBeTruthy();
    });

    it('does not open the modal again when the deal already has a lost_reason and stays in a lost stage', async () => {
      const wrapper = mountIndex();
      await flushPromises();

      const form = await openDealForEdit(wrapper, 2);
      // O negócio já estava na etapa perdida com motivo: o stub de
      // open-deal-in-2 informa deal_stage_id 2 mas lost_reason null por
      // padrão, então simulamos aqui o caso realista (motivo já setado).
      form.vm.$emit('submit', {
        title: 'Negócio 1',
        deal_stage_id: 2,
        lost_reason: 'já tinha motivo',
      });
      await flushPromises();

      expect(dispatch).toHaveBeenCalledWith('deals/update', {
        id: 1,
        title: 'Negócio 1',
        deal_stage_id: 2,
        lost_reason: 'já tinha motivo',
      });
      expect(
        wrapper.findComponent({ name: 'DealLostReasonModal' }).exists()
      ).toBe(false);
    });
  });
});
