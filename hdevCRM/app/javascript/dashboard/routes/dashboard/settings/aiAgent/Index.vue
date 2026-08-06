<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import AiAgentAPI from 'dashboard/api/aiAgent';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();

const DEFAULT_MODEL = 'claude-opus-4-8';
const MODEL_OPTIONS = [
  'claude-opus-4-8',
  'claude-sonnet-5',
  'claude-haiku-4-5',
];

const config = reactive({
  ai_agent_enabled: false,
  ai_agent_prompt: '',
  ai_agent_model: DEFAULT_MODEL,
});
const usage = ref(null);
const isSaving = ref(false);

const usagePercentage = computed(() => {
  if (!usage.value?.monthly_limit) return null;
  return Math.min(
    100,
    Math.round((usage.value.tokens_used / usage.value.monthly_limit) * 100)
  );
});

const formattedCost = computed(() => {
  const cost = usage.value?.usage?.cost;
  if (cost === undefined || cost === null) return '—';
  return `US$ ${Number(cost).toFixed(4)}`;
});

const fetchAll = async () => {
  try {
    const [{ data: configData }, { data: usageData }] = await Promise.all([
      AiAgentAPI.getConfig(),
      AiAgentAPI.getUsage(),
    ]);
    config.ai_agent_enabled = Boolean(configData.ai_agent_enabled);
    config.ai_agent_prompt = configData.ai_agent_prompt || '';
    config.ai_agent_model = configData.ai_agent_model || DEFAULT_MODEL;
    usage.value = usageData;
  } catch {
    useAlert(t('AI_AGENT_SETTINGS.API.FETCH_ERROR'));
  }
};

const saveConfig = async () => {
  isSaving.value = true;
  try {
    await AiAgentAPI.updateConfig({
      ai_agent_enabled: config.ai_agent_enabled,
      ai_agent_prompt: config.ai_agent_prompt,
      ai_agent_model: config.ai_agent_model,
    });
    useAlert(t('AI_AGENT_SETTINGS.API.SUCCESS'));
  } catch {
    useAlert(t('AI_AGENT_SETTINGS.API.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

onMounted(fetchAll);
</script>

<template>
  <div class="flex flex-col w-full max-w-3xl gap-8 p-8 overflow-auto">
    <div class="flex flex-col gap-1">
      <h1 class="text-2xl font-medium text-n-slate-12">
        {{ t('AI_AGENT_SETTINGS.HEADER') }}
      </h1>
      <p class="text-sm text-n-slate-11">
        {{ t('AI_AGENT_SETTINGS.DESCRIPTION') }}
      </p>
    </div>

    <section class="flex flex-col gap-5">
      <div
        class="flex items-center justify-between gap-4 p-4 border rounded-xl border-n-weak"
      >
        <div class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('AI_AGENT_SETTINGS.FORM.ENABLED_LABEL') }}
          </span>
          <span class="text-sm text-n-slate-11">
            {{ t('AI_AGENT_SETTINGS.FORM.ENABLED_NOTE') }}
          </span>
        </div>
        <ToggleSwitch v-model="config.ai_agent_enabled" />
      </div>

      <label class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('AI_AGENT_SETTINGS.FORM.MODEL_LABEL') }}
        </span>
        <select
          v-model="config.ai_agent_model"
          class="w-full px-3 py-2 text-sm border rounded-lg outline-none border-n-weak bg-n-background text-n-slate-12"
        >
          <option v-for="model in MODEL_OPTIONS" :key="model" :value="model">
            {{ model }}
          </option>
        </select>
      </label>

      <label class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('AI_AGENT_SETTINGS.FORM.PROMPT_LABEL') }}
        </span>
        <textarea
          v-model="config.ai_agent_prompt"
          rows="6"
          :placeholder="t('AI_AGENT_SETTINGS.FORM.PROMPT_PLACEHOLDER')"
          class="w-full px-3 py-2 text-sm border rounded-lg outline-none resize-y border-n-weak bg-n-background text-n-slate-12"
        />
      </label>

      <div>
        <NextButton
          :label="t('AI_AGENT_SETTINGS.FORM.SAVE')"
          :is-loading="isSaving"
          @click="saveConfig"
        />
      </div>
    </section>

    <section v-if="usage" class="flex flex-col gap-4">
      <h2 class="text-lg font-medium text-n-slate-12">
        {{ t('AI_AGENT_SETTINGS.USAGE.TITLE') }}
      </h2>

      <div
        v-if="usage.exceeded"
        class="px-4 py-3 text-sm border rounded-lg border-n-ruby-8 text-n-ruby-11"
      >
        {{ t('AI_AGENT_SETTINGS.USAGE.EXCEEDED') }}
      </div>

      <div class="flex flex-col gap-2 p-4 border rounded-xl border-n-weak">
        <div class="flex items-center justify-between text-sm">
          <span class="text-n-slate-11">
            {{ t('AI_AGENT_SETTINGS.USAGE.TOKENS_USED') }}
          </span>
          <span class="font-medium text-n-slate-12">
            {{ usage.tokens_used.toLocaleString() }}
            <template v-if="usage.monthly_limit">
              / {{ usage.monthly_limit.toLocaleString() }}
            </template>
            <template v-else>
              · {{ t('AI_AGENT_SETTINGS.USAGE.UNLIMITED') }}
            </template>
          </span>
        </div>
        <div
          v-if="usagePercentage !== null"
          class="w-full h-2 overflow-hidden rounded-full bg-n-alpha-black2"
        >
          <div
            class="h-full rounded-full"
            :class="usagePercentage >= 100 ? 'bg-n-ruby-9' : 'bg-n-blue-9'"
            :style="{ width: `${usagePercentage}%` }"
          />
        </div>
      </div>

      <div class="grid grid-cols-3 gap-4">
        <div class="flex flex-col gap-1 p-4 border rounded-xl border-n-weak">
          <span class="text-xs text-n-slate-11">
            {{ t('AI_AGENT_SETTINGS.USAGE.INPUT_TOKENS') }}
          </span>
          <span class="text-lg font-medium text-n-slate-12">
            {{ (usage.usage?.input_tokens || 0).toLocaleString() }}
          </span>
        </div>
        <div class="flex flex-col gap-1 p-4 border rounded-xl border-n-weak">
          <span class="text-xs text-n-slate-11">
            {{ t('AI_AGENT_SETTINGS.USAGE.OUTPUT_TOKENS') }}
          </span>
          <span class="text-lg font-medium text-n-slate-12">
            {{ (usage.usage?.output_tokens || 0).toLocaleString() }}
          </span>
        </div>
        <div class="flex flex-col gap-1 p-4 border rounded-xl border-n-weak">
          <span class="text-xs text-n-slate-11">
            {{ t('AI_AGENT_SETTINGS.USAGE.COST') }}
          </span>
          <span class="text-lg font-medium text-n-slate-12">
            {{ formattedCost }}
          </span>
        </div>
      </div>
    </section>
  </div>
</template>
