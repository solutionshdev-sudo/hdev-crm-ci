<script setup>
import { computed } from 'vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const props = defineProps({
  deal: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['click']);

const formattedValue = computed(() => {
  const value = Number(props.deal.value || 0);
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: props.deal.currency || 'BRL',
  }).format(value);
});
</script>

<template>
  <button
    type="button"
    class="flex flex-col w-full gap-2 p-3 text-left border shadow-sm cursor-grab rounded-xl bg-n-solid-1 border-n-weak hover:border-n-slate-6"
    @click="emit('click', deal)"
  >
    <span class="text-sm font-medium break-words text-n-slate-12">
      {{ deal.title }}
    </span>
    <span class="text-sm font-semibold text-n-blue-11">
      {{ formattedValue }}
    </span>
    <div class="flex items-center justify-between w-full">
      <span class="text-xs truncate text-n-slate-11">
        {{ deal.contact?.name }}
      </span>
      <Avatar
        v-if="deal.assignee"
        :name="deal.assignee.name"
        :src="deal.assignee.thumbnail"
        :size="20"
        rounded-full
      />
    </div>
  </button>
</template>
