<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { Handle, Position } from '@vue-flow/core';
import { NODE_TYPES, outputHandles } from './nodeTypes';

const props = defineProps({
  id: {
    type: String,
    required: true,
  },
  type: {
    type: String,
    required: true,
  },
  data: {
    type: Object,
    default: () => ({}),
  },
  selected: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();

const config = computed(() => NODE_TYPES[props.type] || {});

const handles = computed(() =>
  outputHandles({ type: props.type, data: props.data })
);

const handleLabel = handle => {
  if (props.type === 'question') {
    const option = (props.data.options || []).find(
      item => item.id === handle
    );
    if (option) return option.title;
  }
  const key = `CHATBOTS.BUILDER.HANDLES.${handle.toUpperCase()}`;
  const translated = t(key);
  return translated === key ? handle : translated;
};

const summary = computed(() => {
  const data = props.data || {};
  return (
    data.content ||
    data.message ||
    data.prompt ||
    data.url ||
    data.title_template ||
    ''
  );
});
</script>

<template>
  <div
    class="min-w-[180px] max-w-[240px] rounded-xl bg-n-solid-1 shadow-md outline outline-1"
    :class="selected ? 'outline-n-brand outline-2' : 'outline-n-weak'"
  >
    <Handle
      v-if="type !== 'start'"
      type="target"
      :position="Position.Left"
      class="!bg-n-slate-9 !w-2.5 !h-2.5"
    />

    <div
      class="flex items-center gap-2 px-3 py-2 rounded-t-xl"
      :style="{ backgroundColor: `${config.color}22` }"
    >
      <span :class="config.icon" class="size-4" :style="{ color: config.color }" />
      <span class="text-xs font-semibold text-n-slate-12">
        {{ t(`CHATBOTS.BUILDER.NODES.${type.toUpperCase()}`) }}
      </span>
    </div>

    <p
      v-if="summary"
      class="px-3 py-2 text-xs break-words text-n-slate-11 line-clamp-3"
    >
      {{ summary }}
    </p>

    <div v-if="handles.length > 1" class="flex flex-col gap-1 px-3 pb-2">
      <div
        v-for="(handle, index) in handles"
        :key="handle"
        class="relative flex items-center justify-end h-5 text-[11px] text-n-slate-10"
      >
        <span class="truncate max-w-[180px]">{{ handleLabel(handle) }}</span>
        <Handle
          :id="handle"
          type="source"
          :position="Position.Right"
          class="!bg-n-slate-9 !w-2.5 !h-2.5"
          :style="{ top: `${index * 0}px`, position: 'absolute', right: '-16px' }"
        />
      </div>
    </div>
    <Handle
      v-else-if="handles.length === 1"
      :id="handles[0]"
      type="source"
      :position="Position.Right"
      class="!bg-n-slate-9 !w-2.5 !h-2.5"
    />
  </div>
</template>
