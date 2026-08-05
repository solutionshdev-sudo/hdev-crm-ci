<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import QRCode from 'qrcode';
import BaileysAPI from 'dashboard/api/inbox/baileys';
import { useAlert } from 'dashboard/composables';
import {
  BAILEYS_TRANSIENT_STATES,
  BAILEYS_NOT_PROVISIONED,
  baileysStatusClass,
  baileysStatusLabelKey,
} from 'dashboard/helper/baileys';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  inboxId: {
    type: [String, Number],
    required: true,
  },
});

const emit = defineEmits(['connected']);

const { t } = useI18n();

// null = nada observado ainda nesta montagem. Não é o mesmo que 'disconnected':
// é o que impede o emit('connected') de disparar na primeira leitura — ver o
// guard em refreshStatus.
const status = ref(null);
const qrDataUrl = ref('');
const pairingCode = ref('');
const errorDetail = ref('');
const lastError = ref('');
const connectedNumber = ref('');
const lastCheckedAt = ref(null);
const isWorking = ref(false);
const reconnectDialogRef = ref(null);
let pollTimer = null;
let pollInterval = null;
let pollFailures = 0;

// O selo precisa continuar vivo depois de conectar — é o que responde "ainda
// está conectada?". Rápido enquanto pareia, devagar no repouso.
const FAST_POLL = 3000;
const SLOW_POLL = 15000;
// Depois disso o serviço é dado como fora do ar e a UI mostra erro em vez de
// "Conectando..." eterno: ~15s durante o pareamento (polling de 3s) e ~75s em
// repouso (15s). Não baixar o contador — o microserviço engasga justamente
// durante o pareamento, e menos tolerância deixa a tela nervosa aí.
const MAX_POLL_FAILURES = 5;

const statusLabel = computed(() => t(baileysStatusLabelKey(status.value)));

const statusBadgeClass = computed(() => baileysStatusClass(status.value));

const isConnected = computed(() => status.value === 'connected');

const isNotProvisioned = computed(
  () => lastError.value === BAILEYS_NOT_PROVISIONED
);

const showErrorDetail = computed(
  () => errorDetail.value && !isConnected.value && !isNotProvisioned.value
);

const lastCheckedLabel = computed(() => {
  if (!lastCheckedAt.value) return '';
  return t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.LAST_CHECK', {
    time: lastCheckedAt.value.toLocaleTimeString(),
  });
});

const desiredInterval = computed(() =>
  BAILEYS_TRANSIENT_STATES.includes(status.value) ? FAST_POLL : SLOW_POLL
);

const refreshStatus = async () => {
  try {
    const { data } = await BaileysAPI.getStatus(props.inboxId);
    pollFailures = 0;
    lastCheckedAt.value = new Date();
    const previous = status.value;
    status.value = data.status || 'disconnected';
    pairingCode.value = data.pairingCode || '';
    lastError.value = data.lastError || '';
    connectedNumber.value =
      data.phoneNumber || data.jid?.split('@')?.[0]?.split(':')?.[0] || '';
    errorDetail.value =
      [data.lastDisconnectReason, data.lastError].filter(Boolean).join(' — ') ||
      '';
    if (data.qr) {
      qrDataUrl.value = await QRCode.toDataURL(data.qr, { width: 264 });
    } else {
      qrDataUrl.value = '';
    }
    // Só emite numa transição observada aqui dentro. Emitir também na primeira
    // leitura fecha um ciclo infinito: o pai responde com dispatch('inboxes/get'),
    // o isFetching troca a raiz do Settings.vue pelo spinner, este componente
    // desmonta e remonta com status zerado, e a primeira leitura acontece de novo.
    if (
      status.value === 'connected' &&
      previous !== null &&
      previous !== 'connected'
    ) {
      emit('connected');
    }
  } catch (error) {
    // Falha de rede/serviço: tolera falhas transitórias, mas depois de N
    // seguidas assume serviço fora do ar. Instância inexistente já vem do
    // Rails como 'disconnected' + not_provisioned, não cai aqui.
    pollFailures += 1;
    if (pollFailures >= MAX_POLL_FAILURES) {
      status.value = 'error';
      errorDetail.value =
        error?.response?.data?.error ||
        t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.SERVICE_UNREACHABLE');
    }
  }
};

const connect = async (usePairingCode = false) => {
  isWorking.value = true;
  try {
    pollFailures = 0;
    errorDetail.value = '';
    lastError.value = '';
    await BaileysAPI.connect(props.inboxId, { usePairingCode });
    await refreshStatus();
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.CONNECT_ERROR')
    );
  } finally {
    isWorking.value = false;
  }
};

const logout = async () => {
  isWorking.value = true;
  try {
    await BaileysAPI.logout(props.inboxId);
    await refreshStatus();
  } catch (error) {
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.LOGOUT_ERROR'));
  } finally {
    isWorking.value = false;
  }
};

// Repareia o mesmo número sem recriar a caixa de entrada: derruba a sessão
// atual e pede um QR novo em seguida.
const reconnect = async () => {
  isWorking.value = true;
  try {
    await BaileysAPI.logout(props.inboxId);
    await BaileysAPI.connect(props.inboxId, { usePairingCode: false });
    pollFailures = 0;
    await refreshStatus();
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.CONNECT_ERROR')
    );
  } finally {
    isWorking.value = false;
    reconnectDialogRef.value?.close();
  }
};

const stopPolling = () => {
  if (!pollTimer) return;
  clearInterval(pollTimer);
  pollTimer = null;
  pollInterval = null;
};

const startPolling = () => {
  if (pollTimer && pollInterval === desiredInterval.value) return;
  stopPolling();
  pollInterval = desiredInterval.value;
  pollTimer = setInterval(refreshStatus, pollInterval);
};

watch(desiredInterval, startPolling);

onMounted(async () => {
  await refreshStatus();
  startPolling();
});

onBeforeUnmount(stopPolling);
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex flex-wrap items-center gap-3">
      <span
        class="inline-flex items-center px-2 py-1 text-xs font-medium rounded-md"
        :class="statusBadgeClass"
      >
        {{ statusLabel }}
      </span>
      <span
        v-if="isConnected && connectedNumber"
        class="text-sm text-n-slate-11"
      >
        {{
          t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.CONNECTED_AS', {
            number: connectedNumber,
          })
        }}
      </span>
      <span v-if="lastCheckedLabel" class="text-xs text-n-slate-10">
        {{ lastCheckedLabel }}
      </span>
    </div>

    <div
      v-if="isNotProvisioned"
      class="p-3 text-sm border rounded-lg bg-n-amber-3 border-n-amber-6 text-n-amber-11"
    >
      {{ t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.NOT_PROVISIONED') }}
    </div>

    <div
      v-if="showErrorDetail"
      class="p-3 text-sm border rounded-lg bg-n-ruby-3 border-n-ruby-6 text-n-ruby-11"
    >
      {{ t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.ERROR_DETAIL') }}:
      <span class="font-mono">{{ errorDetail }}</span>
    </div>

    <div
      v-if="qrDataUrl"
      class="flex flex-col items-center gap-3 p-6 border rounded-xl border-n-weak bg-n-solid-1"
    >
      <img
        :src="qrDataUrl"
        :alt="t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.QR_ALT')"
        class="rounded-lg w-[264px] h-[264px]"
      />
      <p class="text-sm text-center text-n-slate-11">
        {{ t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.QR_HELP') }}
      </p>
    </div>

    <div
      v-if="pairingCode"
      class="flex flex-col items-center gap-2 p-6 border rounded-xl border-n-weak bg-n-solid-1"
    >
      <span class="font-mono text-3xl tracking-widest text-n-slate-12">
        {{ pairingCode }}
      </span>
      <p class="text-sm text-center text-n-slate-11">
        {{ t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.PAIRING_HELP') }}
      </p>
    </div>

    <div class="flex flex-wrap gap-2">
      <NextButton
        v-if="!isConnected"
        :is-loading="isWorking"
        :label="t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.CONNECT_QR')"
        @click="connect(false)"
      />
      <NextButton
        v-if="!isConnected"
        :is-loading="isWorking"
        faded
        :label="t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.CONNECT_CODE')"
        @click="connect(true)"
      />
      <NextButton
        v-if="isConnected"
        :is-loading="isWorking"
        faded
        :label="t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.RECONNECT')"
        @click="reconnectDialogRef?.open()"
      />
      <NextButton
        v-if="isConnected"
        :is-loading="isWorking"
        ruby
        faded
        :label="t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.LOGOUT')"
        @click="logout"
      />
    </div>

    <Dialog
      ref="reconnectDialogRef"
      type="alert"
      :title="t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.RECONNECT')"
      :description="
        t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.RECONNECT_CONFIRM')
      "
      :confirm-button-label="
        t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.RECONNECT')
      "
      :is-loading="isWorking"
      @confirm="reconnect"
    />
  </div>
</template>
