<script setup>
import { computed, markRaw, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useDebounceFn } from '@vueuse/core';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
// CSS estrutural do vendor (posicionamento/pointer-events) — exceção
// registrada no AGENTS.md; o tema é 100% Tailwind nos nós.
import '@vue-flow/core/dist/style.css';
import FlowNode from './flow/FlowNode.vue';
import FlowInspector from './flow/FlowInspector.vue';
import { NODE_TYPES, PALETTE_TYPES, emptyFlow, newNodeId } from './flow/nodeTypes';
import NextButton from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const chatbotId = Number(route.params.chatbotId);
const chatbot = ref(null);
const nodes = ref([]);
const edges = ref([]);
const selectedNode = ref(null);
const isSaving = ref(false);
const lastSavedAt = ref(null);

const nodeTypes = Object.keys(NODE_TYPES).reduce((map, type) => {
  map[type] = markRaw(FlowNode);
  return map;
}, {});

const {
  onConnect,
  onNodeClick,
  onPaneClick,
  onEdgeClick,
  addEdges,
  removeEdges,
  vueFlowRef,
  getViewport,
  setViewport,
  zoomIn,
  zoomOut,
  fitView,
  project,
} = useVueFlow();

// A maioria dos handles é 1:1 — conectar de novo substitui a aresta anterior.
onConnect(connection => {
  const existing = edges.value.filter(
    edge =>
      edge.source === connection.source &&
      (edge.sourceHandle || null) === (connection.sourceHandle || null)
  );
  if (existing.length) removeEdges(existing);
  addEdges([{ ...connection, id: newNodeId('edge') }]);
});

onNodeClick(({ node }) => {
  selectedNode.value = node;
});

onPaneClick(() => {
  selectedNode.value = null;
});

onEdgeClick(({ edge }) => {
  removeEdges([edge]);
});

const addNode = type => {
  const bounds = vueFlowRef.value?.getBoundingClientRect();
  const center = project({
    x: (bounds?.width || 800) / 2,
    y: (bounds?.height || 600) / 2,
  });
  nodes.value.push({
    id: newNodeId(type),
    type,
    position: {
      x: center.x + Math.random() * 40,
      y: center.y + Math.random() * 40,
    },
    data: NODE_TYPES[type].data(),
  });
};

const removeNode = nodeId => {
  nodes.value = nodes.value.filter(node => node.id !== nodeId);
  edges.value = edges.value.filter(
    edge => edge.source !== nodeId && edge.target !== nodeId
  );
  selectedNode.value = null;
};

const serializeFlow = () => ({
  version: 1,
  viewport: getViewport(),
  nodes: nodes.value.map(node => ({
    id: node.id,
    type: node.type,
    position: node.position,
    data: node.data,
  })),
  edges: edges.value.map(edge => ({
    id: edge.id,
    source: edge.source,
    target: edge.target,
    sourceHandle: edge.sourceHandle || undefined,
  })),
});

const save = async () => {
  isSaving.value = true;
  try {
    await store.dispatch('chatbots/update', {
      id: chatbotId,
      chatbot: { flow: serializeFlow() },
    });
    lastSavedAt.value = new Date();
  } catch (error) {
    useAlert(error.message || t('CHATBOTS.BUILDER.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const autosave = useDebounceFn(save, 1500);

watch([nodes, edges], () => autosave(), { deep: true });

const savedLabel = computed(() => {
  if (isSaving.value) return t('CHATBOTS.BUILDER.SAVING');
  if (lastSavedAt.value) return t('CHATBOTS.BUILDER.SAVED');
  return '';
});

onMounted(async () => {
  const record = await store.dispatch('chatbots/show', chatbotId);
  chatbot.value = record;
  const flow = record.flow?.nodes?.length ? record.flow : emptyFlow();
  nodes.value = flow.nodes.map(node => ({ ...node }));
  edges.value = (flow.edges || []).map(edge => ({ ...edge }));
  if (flow.viewport) setViewport(flow.viewport);
  await Promise.all([
    store.dispatch('teams/get'),
    store.dispatch('agents/get'),
    store.dispatch('dealPipelines/get'),
  ]);
});
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden bg-n-background">
    <header
      class="flex items-center justify-between flex-shrink-0 gap-4 px-4 py-3 border-b border-n-weak"
    >
      <div class="flex items-center gap-3">
        <NextButton
          ghost
          slate
          icon="i-lucide-arrow-left"
          @click="router.push({ name: 'chatbots_list', params: route.params })"
        />
        <h1 class="text-base font-medium text-n-slate-12">
          {{ chatbot?.name }}
        </h1>
        <span class="text-xs text-n-slate-10">{{ savedLabel }}</span>
      </div>
      <div class="flex items-center gap-2">
        <NextButton ghost slate icon="i-lucide-zoom-in" @click="zoomIn()" />
        <NextButton ghost slate icon="i-lucide-zoom-out" @click="zoomOut()" />
        <NextButton ghost slate icon="i-lucide-maximize" @click="fitView()" />
        <NextButton
          solid
          blue
          :is-loading="isSaving"
          :label="t('CHATBOTS.BUILDER.SAVE')"
          @click="save"
        />
      </div>
    </header>

    <div class="flex flex-1 min-h-0">
      <!-- Paleta -->
      <aside
        class="flex flex-col flex-shrink-0 w-48 gap-1 p-3 overflow-y-auto border-r border-n-weak bg-n-solid-1"
      >
        <span class="mb-1 text-xs font-semibold uppercase text-n-slate-10">
          {{ t('CHATBOTS.BUILDER.PALETTE') }}
        </span>
        <button
          v-for="type in PALETTE_TYPES"
          :key="type"
          type="button"
          class="flex items-center gap-2 px-2 py-1.5 text-sm text-left rounded-lg text-n-slate-12 hover:bg-n-alpha-1"
          @click="addNode(type)"
        >
          <span
            :class="NODE_TYPES[type].icon"
            class="size-4"
            :style="{ color: NODE_TYPES[type].color }"
          />
          {{ t(`CHATBOTS.BUILDER.NODES.${type.toUpperCase()}`) }}
        </button>
      </aside>

      <!-- Canvas -->
      <div class="relative flex-1 min-w-0">
        <VueFlow
          v-model:nodes="nodes"
          v-model:edges="edges"
          :node-types="nodeTypes"
          :default-edge-options="{ type: 'smoothstep' }"
          :min-zoom="0.2"
          :max-zoom="2"
          fit-view-on-init
          class="w-full h-full"
        >
          <Background :gap="20" />
        </VueFlow>
      </div>

      <!-- Inspector -->
      <FlowInspector
        v-if="selectedNode"
        :key="selectedNode.id"
        :node="selectedNode"
        @remove="removeNode"
      />
    </div>
  </div>
</template>
