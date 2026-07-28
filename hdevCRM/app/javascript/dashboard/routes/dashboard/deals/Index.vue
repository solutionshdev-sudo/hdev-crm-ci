<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import DealColumn from './DealColumn.vue';
import DealForm from './DealForm.vue';
import DealActivityFeed from './DealActivityFeed.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const { t } = useI18n();

const pipelines = useMapGetter('dealPipelines/getPipelines');
const getDealsByStage = useMapGetter('deals/getDealsByStage');

const selectedPipelineId = ref(null);
const showCreateModal = ref(false);
const openDeal = ref(null);

const selectedPipeline = computed(() =>
  pipelines.value.find(pipeline => pipeline.id === selectedPipelineId.value)
);

const stages = computed(() => selectedPipeline.value?.stages || []);

const loadDeals = async () => {
  if (!selectedPipelineId.value) return;
  await store.dispatch('deals/get', { pipeline_id: selectedPipelineId.value });
};

const selectPipeline = async pipelineId => {
  selectedPipelineId.value = Number(pipelineId);
  await loadDeals();
};

const onMove = async ({ dealId, stageId, beforeDealId, afterDealId }) => {
  try {
    await store.dispatch('deals/move', {
      id: dealId,
      stageId,
      beforeDealId,
      afterDealId,
    });
  } catch (error) {
    useAlert(t('DEALS.BOARD.MOVE_ERROR'));
    await loadDeals();
  }
};

const createDeal = async dealObj => {
  try {
    await store.dispatch('deals/create', dealObj);
    showCreateModal.value = false;
    useAlert(t('DEALS.BOARD.CREATE_SUCCESS'));
  } catch (error) {
    useAlert(error.message || t('DEALS.BOARD.CREATE_ERROR'));
  }
};

const updateDeal = async dealObj => {
  try {
    await store.dispatch('deals/update', { id: openDeal.value.id, ...dealObj });
    openDeal.value = null;
    useAlert(t('DEALS.BOARD.UPDATE_SUCCESS'));
  } catch (error) {
    useAlert(error.message || t('DEALS.BOARD.UPDATE_ERROR'));
  }
};

const deleteDeal = async () => {
  try {
    await store.dispatch('deals/delete', openDeal.value.id);
    openDeal.value = null;
    useAlert(t('DEALS.BOARD.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(t('DEALS.BOARD.DELETE_ERROR'));
  }
};

onMounted(async () => {
  await Promise.all([
    store.dispatch('dealPipelines/get'),
    store.dispatch('agents/get'),
  ]);
  if (pipelines.value.length) {
    await selectPipeline(pipelines.value[0].id);
  }
});
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden bg-n-background">
    <header
      class="flex items-center justify-between flex-shrink-0 gap-4 px-6 py-4 border-b border-n-weak"
    >
      <div class="flex items-center gap-3">
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ t('DEALS.BOARD.TITLE') }}
        </h1>
        <select
          v-if="pipelines.length > 1"
          class="!mb-0 !w-auto"
          :value="selectedPipelineId"
          @change="selectPipeline($event.target.value)"
        >
          <option
            v-for="pipeline in pipelines"
            :key="pipeline.id"
            :value="pipeline.id"
          >
            {{ pipeline.name }}
          </option>
        </select>
      </div>
      <NextButton
        solid
        blue
        icon="i-lucide-plus"
        :label="t('DEALS.BOARD.NEW_DEAL')"
        @click="showCreateModal = true"
      />
    </header>

    <main class="flex flex-1 gap-4 p-6 overflow-x-auto">
      <DealColumn
        v-for="stage in stages"
        :key="stage.id"
        :stage="stage"
        :deals="getDealsByStage(stage.id)"
        @move="onMove"
        @open-deal="openDeal = $event"
      />
      <p v-if="!stages.length" class="text-sm text-n-slate-11">
        {{ t('DEALS.BOARD.EMPTY') }}
      </p>
    </main>

    <woot-modal
      v-model:show="showCreateModal"
      :on-close="() => (showCreateModal = false)"
    >
      <woot-modal-header :header-title="t('DEALS.BOARD.NEW_DEAL')" />
      <DealForm
        v-if="selectedPipeline"
        :pipeline="selectedPipeline"
        @submit="createDeal"
        @cancel="showCreateModal = false"
      />
    </woot-modal>

    <woot-modal :show="Boolean(openDeal)" :on-close="() => (openDeal = null)">
      <template v-if="openDeal">
        <woot-modal-header :header-title="openDeal.title" />
        <DealForm
          :pipeline="selectedPipeline"
          :deal="openDeal"
          @submit="updateDeal"
          @cancel="openDeal = null"
        />
        <div class="px-6 pb-6">
          <DealActivityFeed :deal-id="openDeal.id" />
          <div class="flex justify-end mt-4">
            <NextButton
              ruby
              faded
              :label="t('DEALS.BOARD.DELETE')"
              @click="deleteDeal"
            />
          </div>
        </div>
      </template>
    </woot-modal>
  </div>
</template>
