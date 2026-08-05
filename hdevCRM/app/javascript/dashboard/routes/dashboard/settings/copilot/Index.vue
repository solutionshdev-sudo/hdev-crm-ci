<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CopilotAPI from 'dashboard/api/copilot';
import MessageList from 'dashboard/components-next/captain/assistant/MessageList.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();

const messages = ref([]);
const newMessage = ref('');
const isLoading = ref(false);
const isApplying = ref(false);
// Substituído a cada proposta, nunca acumulado: cada chamada monta um ToolLoop
// novo e `executed` é só daquele turno.
const pendingChanges = ref([]);

// 422 e 429 já chegam com a frase pronta do Rails; só o resto vira genérico.
const errorMessage = error =>
  error?.response?.data?.error || t('COPILOT.API.ERROR');

const historyForApi = () =>
  messages.value.map(message => ({
    role: message.sender,
    content: message.content,
  }));

const propose = async () => {
  if (!newMessage.value.trim() || isLoading.value) return;

  messages.value.push({
    content: newMessage.value,
    sender: 'user',
    timestamp: new Date().toISOString(),
  });
  newMessage.value = '';
  isLoading.value = true;

  try {
    const { data } = await CopilotAPI.propose(historyForApi());
    messages.value.push({
      content: data.reply,
      sender: 'assistant',
      timestamp: new Date().toISOString(),
    });
    pendingChanges.value = data.changes || [];
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isLoading.value = false;
  }
};

// O preview é a confirmação — o backend garante que nada foi gravado, então
// não há modal aqui.
const apply = async () => {
  isApplying.value = true;

  try {
    await CopilotAPI.apply(pendingChanges.value);
    pendingChanges.value = [];
    useAlert(t('COPILOT.API.APPLIED'));
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isApplying.value = false;
  }
};

const discard = () => {
  pendingChanges.value = [];
};

const handleEnterKey = event => {
  if (event.isComposing) return;
  event.preventDefault();
  propose();
};
</script>

<template>
  <div class="flex flex-col w-full max-w-3xl h-full gap-6 p-8 overflow-hidden">
    <div class="flex flex-col gap-1">
      <h1 class="text-2xl font-medium text-n-slate-12">
        {{ t('COPILOT.HEADER') }}
      </h1>
      <p class="text-sm text-n-slate-11">
        {{ t('COPILOT.DESCRIPTION') }}
      </p>
    </div>

    <div
      class="flex flex-col flex-1 min-h-0 py-6 border rounded-xl border-n-weak"
    >
      <MessageList :messages="messages" :is-loading="isLoading" />

      <div
        v-if="pendingChanges.length"
        class="flex flex-col gap-3 p-4 mx-6 mb-4 border rounded-xl border-n-weak bg-n-alpha-2"
      >
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('COPILOT.PREVIEW.TITLE') }}
        </span>
        <ul class="flex flex-col gap-2 pl-5 text-sm list-disc text-n-slate-11">
          <li
            v-for="(change, index) in pendingChanges"
            :key="index"
            data-test-id="copilot-change"
          >
            {{ change.result }}
          </li>
        </ul>
        <div class="flex gap-2">
          <NextButton
            :label="t('COPILOT.PREVIEW.APPLY')"
            sm
            data-test-id="copilot-apply"
            :is-loading="isApplying"
            @click="apply"
          />
          <NextButton
            :label="t('COPILOT.PREVIEW.DISCARD')"
            sm
            faded
            slate
            data-test-id="copilot-discard"
            :disabled="isApplying"
            @click="discard"
          />
        </div>
      </div>

      <div
        class="flex items-center p-3 mx-6 outline outline-1 bg-n-background outline-n-weak rounded-xl"
      >
        <input
          v-model="newMessage"
          class="flex-1 mb-0 text-sm bg-transparent border-none focus:outline-none text-n-slate-12 placeholder:text-n-slate-10"
          :placeholder="t('COPILOT.PLACEHOLDER')"
          data-test-id="copilot-input"
          @keydown.enter.exact="handleEnterKey"
        />
        <NextButton
          ghost
          sm
          data-test-id="copilot-propose"
          :disabled="!newMessage.trim() || isLoading"
          icon="i-lucide-send"
          @click="propose"
        />
      </div>
    </div>
  </div>
</template>
