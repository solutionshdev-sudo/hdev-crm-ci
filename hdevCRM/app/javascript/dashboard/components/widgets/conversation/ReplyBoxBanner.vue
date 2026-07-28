<script setup>
import { computed, watch } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useI18n } from 'vue-i18n';
import wootConstants from 'dashboard/constants/globals';
import { isBaileysInbox, isBaileysConnected } from 'dashboard/helper/baileys';

import Banner from 'dashboard/components/ui/Banner.vue';

const props = defineProps({
  message: {
    type: String,
    default: '',
  },
  isOnPrivateNote: {
    type: Boolean,
    default: false,
  },
});

const store = useStore();
const router = useRouter();
const { t } = useI18n();
const { isAdmin } = useAdmin();

const currentChat = useMapGetter('getSelectedChat');
const currentUser = useMapGetter('getCurrentUser');
const accountId = useMapGetter('getCurrentAccountId');
const inboxGetter = useMapGetter('inboxes/getInbox');

const currentInbox = computed(() =>
  inboxGetter.value(currentChat.value?.inbox_id)
);

// WhatsApp não-oficial cai sozinho (celular sem rede, sessão expirada). Sem esse
// aviso o agente só descobre quando a mensagem falha.
const showWhatsappDisconnectedBanner = computed(
  () =>
    isBaileysInbox(currentInbox.value) &&
    !isBaileysConnected(currentInbox.value)
);

const goToInboxSettings = () => {
  router.push({
    name: 'settings_inbox_show',
    params: { accountId: accountId.value, inboxId: currentInbox.value.id },
  });
};

// A lista de inboxes é carregada no boot; recarrega ao abrir uma conversa de
// inbox baileys para o aviso não ficar preso num estado velho (não há push de
// inbox por websocket). Com freio de 30s: quem varre a fila troca de conversa
// dezenas de vezes por minuto e o estado não muda nesse ritmo.
const INBOX_REFETCH_INTERVAL = 30 * 1000;
let lastInboxFetchAt = 0;

watch(
  () => currentChat.value?.inbox_id,
  () => {
    if (!isBaileysInbox(currentInbox.value)) return;
    if (Date.now() - lastInboxFetchAt < INBOX_REFETCH_INTERVAL) return;

    lastInboxFetchAt = Date.now();
    store.dispatch('inboxes/get');
  },
  { immediate: true }
);

const assignedAgent = computed({
  get() {
    return currentChat.value?.meta?.assignee;
  },
  set(agent) {
    const agentId = agent ? agent.id : null;
    store.dispatch('setCurrentChatAssignee', {
      conversationId: currentChat.value?.id,
      assignee: agent,
    });
    store.dispatch('assignAgent', {
      conversationId: currentChat.value?.id,
      agentId,
    });
  },
});

const isUserTyping = computed(
  () => props.message !== '' && !props.isOnPrivateNote
);
const isUnassigned = computed(() => !assignedAgent.value);
const isAssignedToOtherAgent = computed(
  () => assignedAgent.value?.id !== currentUser.value?.id
);

const showSelfAssignBanner = computed(() => {
  return (
    isUserTyping.value && (isUnassigned.value || isAssignedToOtherAgent.value)
  );
});

const showBotHandoffBanner = computed(
  () =>
    isUserTyping.value &&
    currentChat.value?.status === wootConstants.STATUS_TYPE.PENDING
);

const botHandoffActionLabel = computed(() => {
  return assignedAgent.value?.id === currentUser.value?.id
    ? t('CONVERSATION.BOT_HANDOFF_REOPEN_ACTION')
    : t('CONVERSATION.BOT_HANDOFF_ACTION');
});

const selfAssignConversation = async () => {
  const { avatar_url, ...rest } = currentUser.value || {};
  assignedAgent.value = { ...rest, thumbnail: avatar_url };
};

const needsAssignmentToCurrentUser = computed(() => {
  return isUnassigned.value || isAssignedToOtherAgent.value;
});

const onClickSelfAssign = async () => {
  try {
    await selfAssignConversation();
    useAlert(t('CONVERSATION.CHANGE_AGENT'));
  } catch (error) {
    useAlert(t('CONVERSATION.CHANGE_AGENT_FAILED'));
  }
};

const reopenConversation = async () => {
  await store.dispatch('toggleStatus', {
    conversationId: currentChat.value?.id,
    status: wootConstants.STATUS_TYPE.OPEN,
  });
};

const onClickBotHandoff = async () => {
  try {
    await reopenConversation();

    if (needsAssignmentToCurrentUser.value) {
      await selfAssignConversation();
    }

    useAlert(t('CONVERSATION.BOT_HANDOFF_SUCCESS'));
  } catch (error) {
    useAlert(t('CONVERSATION.BOT_HANDOFF_ERROR'));
  }
};
</script>

<template>
  <Banner
    v-if="showWhatsappDisconnectedBanner"
    color-scheme="alert"
    action-button-variant="ghost"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="$t('CONVERSATION.WHATSAPP_DISCONNECTED')"
    :has-action-button="isAdmin"
    :action-button-label="$t('CONVERSATION.WHATSAPP_DISCONNECTED_ACTION')"
    @primary-action="goToInboxSettings"
  />
  <Banner
    v-if="showSelfAssignBanner && !showBotHandoffBanner"
    action-button-variant="ghost"
    color-scheme="secondary"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="$t('CONVERSATION.NOT_ASSIGNED_TO_YOU')"
    has-action-button
    :action-button-label="$t('CONVERSATION.ASSIGN_TO_ME')"
    @primary-action="onClickSelfAssign"
  />
  <Banner
    v-if="showBotHandoffBanner"
    action-button-variant="ghost"
    color-scheme="secondary"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="$t('CONVERSATION.BOT_HANDOFF_MESSAGE')"
    has-action-button
    :action-button-label="botHandoffActionLabel"
    @primary-action="onClickBotHandoff"
  />
</template>
