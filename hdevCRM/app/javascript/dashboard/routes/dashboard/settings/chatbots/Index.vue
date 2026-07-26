<script setup>
import { onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { emptyFlow } from './flow/nodeTypes';

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const chatbots = useMapGetter('chatbots/getChatbots');
const inboxes = useMapGetter('inboxes/getInboxes');

const showModal = ref(false);
const name = ref('');
const description = ref('');
const inboxIds = ref([]);

const openBuilder = chatbot => {
  router.push({
    name: 'chatbots_builder',
    params: { ...route.params, chatbotId: chatbot.id },
  });
};

const createChatbot = async () => {
  if (!name.value.trim()) return;
  try {
    const chatbot = await store.dispatch('chatbots/create', {
      chatbot: { name: name.value.trim(), description: description.value, flow: emptyFlow() },
      inbox_ids: inboxIds.value,
    });
    showModal.value = false;
    name.value = '';
    description.value = '';
    inboxIds.value = [];
    openBuilder(chatbot);
  } catch (error) {
    useAlert(error.message || t('CHATBOTS.LIST.CREATE_ERROR'));
  }
};

const toggle = async chatbot => {
  try {
    await store.dispatch('chatbots/toggle', chatbot.id);
  } catch (error) {
    useAlert(error.message || t('CHATBOTS.LIST.TOGGLE_ERROR'));
  }
};

const clone = async chatbot => {
  await store.dispatch('chatbots/clone', chatbot.id);
};

const remove = async chatbot => {
  await store.dispatch('chatbots/delete', chatbot.id);
};

const statusColor = status => {
  if (status === 'active') return 'bg-n-teal-3 text-n-teal-11';
  if (status === 'draft') return 'bg-n-amber-3 text-n-amber-11';
  return 'bg-n-alpha-2 text-n-slate-11';
};

onMounted(() => {
  store.dispatch('chatbots/get');
  store.dispatch('inboxes/get');
});
</script>

<template>
  <div class="flex flex-col w-full h-full gap-6 overflow-auto p-7">
    <BaseSettingsHeader
      :title="t('CHATBOTS.LIST.TITLE')"
      :description="t('CHATBOTS.LIST.DESCRIPTION')"
      feature-name="chatbots"
    >
      <template #actions>
        <NextButton
          solid
          blue
          icon="i-lucide-plus"
          :label="t('CHATBOTS.LIST.NEW')"
          @click="showModal = true"
        />
      </template>
    </BaseSettingsHeader>

    <p v-if="!chatbots.length" class="text-sm text-n-slate-11">
      {{ t('CHATBOTS.LIST.EMPTY') }}
    </p>

    <div
      v-for="chatbot in chatbots"
      :key="chatbot.id"
      class="flex items-center justify-between p-4 border rounded-xl border-n-weak bg-n-solid-1"
    >
      <div class="flex flex-col min-w-0 gap-1">
        <div class="flex items-center gap-2">
          <span class="text-sm font-medium text-n-slate-12">
            {{ chatbot.name }}
          </span>
          <span
            class="px-2 py-0.5 text-xs font-medium rounded-md"
            :class="statusColor(chatbot.status)"
          >
            {{ t(`CHATBOTS.LIST.STATUS.${chatbot.status.toUpperCase()}`) }}
          </span>
        </div>
        <span class="text-xs truncate text-n-slate-11">
          {{
            inboxes
              .filter(inbox => chatbot.inbox_ids.includes(inbox.id))
              .map(inbox => inbox.name)
              .join(', ') || t('CHATBOTS.LIST.NO_INBOX')
          }}
        </span>
      </div>
      <div class="flex items-center flex-shrink-0 gap-2">
        <NextButton
          faded
          slate
          :label="t('CHATBOTS.LIST.EDIT_FLOW')"
          @click="openBuilder(chatbot)"
        />
        <NextButton
          faded
          :slate="chatbot.status === 'active'"
          :teal="chatbot.status !== 'active'"
          :label="
            chatbot.status === 'active'
              ? t('CHATBOTS.LIST.DEACTIVATE')
              : t('CHATBOTS.LIST.ACTIVATE')
          "
          @click="toggle(chatbot)"
        />
        <NextButton ghost slate icon="i-lucide-copy" @click="clone(chatbot)" />
        <NextButton ghost ruby icon="i-lucide-trash-2" @click="remove(chatbot)" />
      </div>
    </div>

    <woot-modal v-model:show="showModal" :on-close="() => (showModal = false)">
      <woot-modal-header :header-title="t('CHATBOTS.LIST.NEW')" />
      <form class="flex flex-col gap-4 p-6" @submit.prevent="createChatbot">
        <label>
          {{ t('CHATBOTS.FORM.NAME') }}
          <input v-model="name" type="text" />
        </label>
        <label>
          {{ t('CHATBOTS.FORM.DESCRIPTION') }}
          <input v-model="description" type="text" />
        </label>
        <label>
          {{ t('CHATBOTS.FORM.INBOXES') }}
          <select v-model="inboxIds" multiple class="!h-32">
            <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
              {{ inbox.name }}
            </option>
          </select>
        </label>
        <div class="flex justify-end gap-2">
          <NextButton
            type="button"
            faded
            slate
            :label="t('CHATBOTS.FORM.CANCEL')"
            @click="showModal = false"
          />
          <NextButton type="submit" solid blue :label="t('CHATBOTS.FORM.CREATE')" />
        </div>
      </form>
    </woot-modal>
  </div>
</template>
