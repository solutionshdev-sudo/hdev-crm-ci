<script setup>
import { computed } from 'vue';
import Draggable from 'vuedraggable';
import DealCard from './DealCard.vue';

const props = defineProps({
  stage: {
    type: Object,
    required: true,
  },
  deals: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['move', 'openDeal']);

const totalValue = computed(() => {
  const total = props.deals.reduce(
    (sum, deal) => sum + Number(deal.value || 0),
    0
  );
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(total);
});

// vuedraggable precisa de um proxy gravável; o pai é a fonte da verdade e o
// evento `move` leva os vizinhos pro cálculo de posição no backend.
const localDeals = computed({
  get: () => props.deals,
  set: () => {},
});

const onDragChange = event => {
  const moved = event.added || event.moved;
  if (!moved) return;
  const { element, newIndex } = moved;
  const without = props.deals.filter(deal => deal.id !== element.id);
  const before = without[newIndex - 1];
  const after = without[newIndex];
  emit('move', {
    dealId: element.id,
    stageId: props.stage.id,
    beforeDealId: before?.id,
    afterDealId: after?.id,
  });
};
</script>

<template>
  <div
    class="flex flex-col flex-shrink-0 w-72 max-h-full rounded-xl bg-n-alpha-1"
  >
    <div class="flex items-center justify-between px-3 py-2.5">
      <div class="flex items-center gap-2 min-w-0">
        <span
          class="size-[10px] rounded-sm flex-shrink-0"
          :style="{ backgroundColor: stage.color }"
        />
        <span class="text-sm font-medium truncate text-n-slate-12">
          {{ stage.name }}
        </span>
        <span class="text-xs text-n-slate-10">{{ deals.length }}</span>
      </div>
      <span class="text-xs font-medium text-n-slate-11">{{ totalValue }}</span>
    </div>

    <Draggable
      v-model="localDeals"
      group="deals"
      item-key="id"
      class="flex flex-col flex-1 gap-2 px-2 pb-2 overflow-y-auto min-h-[80px]"
      ghost-class="opacity-50"
      @change="onDragChange"
    >
      <template #item="{ element }">
        <DealCard :deal="element" @click="emit('openDeal', element)" />
      </template>
    </Draggable>
  </div>
</template>
