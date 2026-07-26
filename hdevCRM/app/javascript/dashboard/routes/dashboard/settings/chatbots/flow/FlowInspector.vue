<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { newNodeId } from './nodeTypes';

const props = defineProps({
  node: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['remove']);

const { t } = useI18n();

const teams = useMapGetter('teams/getTeams');
const agents = useMapGetter('agents/getAgents');
const pipelines = useMapGetter('dealPipelines/getPipelines');

// node.data é reativo — edições aqui refletem direto no canvas.
const data = computed(() => props.node.data);

const selectedPipeline = computed(() =>
  pipelines.value.find(pipeline => pipeline.id === data.value.pipeline_id)
);

const addOption = () => {
  data.value.options.push({ id: newNodeId('opt'), title: '' });
};

const removeOption = index => {
  data.value.options.splice(index, 1);
};

const addRule = () => {
  data.value.rules.push({ left: '', operator: 'equals', right: '' });
};

const removeRule = index => {
  data.value.rules.splice(index, 1);
};

const tagsAsText = key =>
  computed({
    get: () => (data.value[key] || []).join(', '),
    set: value => {
      data.value[key] = value
        .split(',')
        .map(item => item.trim())
        .filter(Boolean);
    },
  });

const addTags = tagsAsText('add');
const removeTags = tagsAsText('remove');

const OPERATORS = [
  'equals',
  'not_equals',
  'contains',
  'not_contains',
  'starts_with',
  'greater_than',
  'less_than',
  'is_present',
  'is_blank',
  'matches_regex',
];

const VALIDATIONS = ['none', 'email', 'phone', 'number', 'date', 'cpf', 'cnpj', 'regex'];
</script>

<template>
  <aside
    class="flex flex-col w-80 gap-4 p-4 overflow-y-auto border-l border-n-weak bg-n-solid-1"
  >
    <div class="flex items-center justify-between">
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ t(`CHATBOTS.BUILDER.NODES.${node.type.toUpperCase()}`) }}
      </h3>
      <NextButton
        v-if="node.type !== 'start'"
        ghost
        ruby
        sm
        icon="i-lucide-trash-2"
        @click="emit('remove', node.id)"
      />
    </div>

    <!-- message / question / collect: texto principal -->
    <label v-if="'content' in data">
      {{ t('CHATBOTS.BUILDER.FIELDS.CONTENT') }}
      <textarea v-model="data.content" rows="4" />
      <span class="text-xs text-n-slate-10">
        {{ t('CHATBOTS.BUILDER.FIELDS.VARIABLES_HINT') }}
      </span>
    </label>

    <!-- question -->
    <template v-if="node.type === 'question'">
      <label>
        {{ t('CHATBOTS.BUILDER.FIELDS.INPUT_TYPE') }}
        <select v-model="data.input_type">
          <option value="buttons">
            {{ t('CHATBOTS.BUILDER.FIELDS.INPUT_TYPES.BUTTONS') }}
          </option>
          <option value="free_text">
            {{ t('CHATBOTS.BUILDER.FIELDS.INPUT_TYPES.FREE_TEXT') }}
          </option>
        </select>
      </label>
      <div v-if="data.input_type === 'buttons'" class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CHATBOTS.BUILDER.FIELDS.OPTIONS') }}
        </span>
        <div
          v-for="(option, index) in data.options"
          :key="option.id"
          class="flex items-center gap-2"
        >
          <input v-model="option.title" type="text" class="!mb-0" />
          <NextButton
            ghost
            ruby
            sm
            icon="i-lucide-x"
            @click="removeOption(index)"
          />
        </div>
        <div>
          <NextButton
            faded
            slate
            sm
            icon="i-lucide-plus"
            :label="t('CHATBOTS.BUILDER.FIELDS.ADD_OPTION')"
            @click="addOption"
          />
        </div>
      </div>
      <label>
        {{ t('CHATBOTS.BUILDER.FIELDS.INVALID_MESSAGE') }}
        <input v-model="data.invalid_message" type="text" />
      </label>
    </template>

    <!-- condition -->
    <template v-if="node.type === 'condition'">
      <label>
        {{ t('CHATBOTS.BUILDER.FIELDS.MODE') }}
        <select v-model="data.mode">
          <option value="all">{{ t('CHATBOTS.BUILDER.FIELDS.MODE_ALL') }}</option>
          <option value="any">{{ t('CHATBOTS.BUILDER.FIELDS.MODE_ANY') }}</option>
        </select>
      </label>
      <div class="flex flex-col gap-2">
        <div
          v-for="(rule, index) in data.rules"
          :key="index"
          class="flex flex-col gap-1 p-2 border rounded-lg border-n-weak"
        >
          <input
            v-model="rule.left"
            type="text"
            class="!mb-0"
            :placeholder="t('CHATBOTS.BUILDER.FIELDS.RULE_LEFT')"
          />
          <select v-model="rule.operator" class="!mb-0">
            <option v-for="operator in OPERATORS" :key="operator" :value="operator">
              {{ t(`CHATBOTS.BUILDER.OPERATORS.${operator.toUpperCase()}`) }}
            </option>
          </select>
          <input
            v-model="rule.right"
            type="text"
            class="!mb-0"
            :placeholder="t('CHATBOTS.BUILDER.FIELDS.RULE_RIGHT')"
          />
          <NextButton
            ghost
            ruby
            sm
            icon="i-lucide-x"
            @click="removeRule(index)"
          />
        </div>
        <div>
          <NextButton
            faded
            slate
            sm
            icon="i-lucide-plus"
            :label="t('CHATBOTS.BUILDER.FIELDS.ADD_RULE')"
            @click="addRule"
          />
        </div>
      </div>
    </template>

    <!-- collect -->
    <template v-if="node.type === 'collect'">
      <label>
        {{ t('CHATBOTS.BUILDER.FIELDS.VALIDATION') }}
        <select v-model="data.validation">
          <option v-for="validation in VALIDATIONS" :key="validation" :value="validation">
            {{ t(`CHATBOTS.BUILDER.VALIDATIONS.${validation.toUpperCase()}`) }}
          </option>
        </select>
      </label>
      <label v-if="data.validation === 'regex'">
        {{ t('CHATBOTS.BUILDER.FIELDS.REGEX') }}
        <input v-model="data.regex" type="text" />
      </label>
      <label>
        {{ t('CHATBOTS.BUILDER.FIELDS.MAP_TO') }}
        <select v-model="data.map_to">
          <option value="">{{ t('CHATBOTS.BUILDER.FIELDS.MAP_TO_NONE') }}</option>
          <option value="contact.name">{{ t('CHATBOTS.BUILDER.FIELDS.MAP_TO_NAME') }}</option>
          <option value="contact.email">{{ t('CHATBOTS.BUILDER.FIELDS.MAP_TO_EMAIL') }}</option>
          <option value="contact.phone_number">
            {{ t('CHATBOTS.BUILDER.FIELDS.MAP_TO_PHONE') }}
          </option>
        </select>
      </label>
      <label>
        {{ t('CHATBOTS.BUILDER.FIELDS.INVALID_MESSAGE') }}
        <input v-model="data.invalid_message" type="text" />
      </label>
    </template>

    <!-- save_as compartilhado -->
    <label v-if="'save_as' in data">
      {{ t('CHATBOTS.BUILDER.FIELDS.SAVE_AS') }}
      <input
        v-model="data.save_as"
        type="text"
        :placeholder="t('CHATBOTS.BUILDER.FIELDS.SAVE_AS_PLACEHOLDER')"
      />
    </label>

    <!-- delay -->
    <label v-if="node.type === 'delay'">
      {{ t('CHATBOTS.BUILDER.FIELDS.DELAY_SECONDS') }}
      <input v-model.number="data.seconds" type="number" min="1" max="86400" />
    </label>

    <!-- handoff -->
    <template v-if="node.type === 'handoff'">
      <label>
        {{ t('CHATBOTS.BUILDER.FIELDS.HANDOFF_MESSAGE') }}
        <textarea v-model="data.message" rows="2" />
      </label>
      <label>
        {{ t('CHATBOTS.BUILDER.FIELDS.ASSIGN_TO') }}
        <select v-model="data.assign_to">
          <option value="none">{{ t('CHATBOTS.BUILDER.FIELDS.ASSIGN_NONE') }}</option>
          <option value="team">{{ t('CHATBOTS.BUILDER.FIELDS.ASSIGN_TEAM') }}</option>
          <option value="agent">{{ t('CHATBOTS.BUILDER.FIELDS.ASSIGN_AGENT') }}</option>
        </select>
      </label>
      <label v-if="data.assign_to === 'team'">
        {{ t('CHATBOTS.BUILDER.FIELDS.TEAM') }}
        <select v-model="data.team_id">
          <option v-for="team in teams" :key="team.id" :value="team.id">
            {{ team.name }}
          </option>
        </select>
      </label>
      <label v-if="data.assign_to === 'agent'">
        {{ t('CHATBOTS.BUILDER.FIELDS.AGENT') }}
        <select v-model="data.agent_id">
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
      </label>
    </template>

    <!-- tag -->
    <template v-if="node.type === 'tag'">
      <label>
        {{ t('CHATBOTS.BUILDER.FIELDS.TAGS_ADD') }}
        <input v-model="addTags" type="text" placeholder="vip, lead-quente" />
      </label>
      <label>
        {{ t('CHATBOTS.BUILDER.FIELDS.TAGS_REMOVE') }}
        <input v-model="removeTags" type="text" />
      </label>
    </template>

    <!-- webhook -->
    <template v-if="node.type === 'webhook'">
      <label>
        {{ t('CHATBOTS.BUILDER.FIELDS.METHOD') }}
        <select v-model="data.method">
          <option value="post">POST</option>
          <option value="get">GET</option>
        </select>
      </label>
      <label>
        URL
        <input v-model="data.url" type="text" placeholder="https://..." />
      </label>
    </template>

    <!-- ai -->
    <template v-if="node.type === 'ai'">
      <label>
        {{ t('CHATBOTS.BUILDER.FIELDS.AI_PROMPT') }}
        <textarea v-model="data.prompt" rows="4" />
      </label>
      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <input v-model="data.send_reply" type="checkbox" />
        {{ t('CHATBOTS.BUILDER.FIELDS.AI_SEND_REPLY') }}
      </label>
    </template>

    <!-- deal -->
    <template v-if="node.type === 'deal'">
      <label>
        {{ t('CHATBOTS.BUILDER.FIELDS.PIPELINE') }}
        <select v-model="data.pipeline_id">
          <option v-for="pipeline in pipelines" :key="pipeline.id" :value="pipeline.id">
            {{ pipeline.name }}
          </option>
        </select>
      </label>
      <label v-if="selectedPipeline">
        {{ t('CHATBOTS.BUILDER.FIELDS.STAGE') }}
        <select v-model="data.stage_id">
          <option v-for="stage in selectedPipeline.stages" :key="stage.id" :value="stage.id">
            {{ stage.name }}
          </option>
        </select>
      </label>
      <label>
        {{ t('CHATBOTS.BUILDER.FIELDS.DEAL_TITLE') }}
        <input v-model="data.title_template" type="text" placeholder="{{contact.name}}" />
      </label>
      <label>
        {{ t('CHATBOTS.BUILDER.FIELDS.DEAL_VALUE') }}
        <input v-model="data.value_template" type="text" placeholder="0" />
      </label>
    </template>

    <!-- end -->
    <template v-if="node.type === 'end'">
      <label>
        {{ t('CHATBOTS.BUILDER.FIELDS.END_MESSAGE') }}
        <textarea v-model="data.message" rows="2" />
      </label>
      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <input v-model="data.resolve_conversation" type="checkbox" />
        {{ t('CHATBOTS.BUILDER.FIELDS.RESOLVE_CONVERSATION') }}
      </label>
    </template>
  </aside>
</template>
