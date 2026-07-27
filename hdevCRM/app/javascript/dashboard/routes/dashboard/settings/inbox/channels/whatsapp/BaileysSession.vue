<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import QRCode from 'qrcode';
import BaileysAPI from 'dashboard/api/inbox/baileys';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  inboxId: {
    type: [String, Number],
    required: true,
  },
});

const emit = defineEmits(['connected']);

const { t } = useI18n();

const status = ref('disconnected');
const qrDataUrl = ref('');
const pairingCode = ref('');
const errorDetail = ref('');
const isWorking = ref(false);
let pollTimer = null;
let pollFailures = 0;

const POLLING_STATES = ['connecting', 'qr', 'pairing'];
// Depois disso o serviço é dado como fora do ar e a UI mostra erro em vez
// de "Conectando..." eterno (~15s com polling de 3s).
const MAX_POLL_FAILURES = 5;

const statusLabel = computed(() =>
  t(`INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.STATUS.${status.value.toUpperCase()}`)
);

const statusBadgeClass = computed(() => {
  if (status.value === 'connected') return 'bg-n-teal-3 text-n-teal-11';
  if (POLLING_STATES.includes(status.value)) return 'bg-n-amber-3 text-n-amber-11';
  return 'bg-n-ruby-3 text-n-ruby-11';
});

const showErrorDetail = computed(
  () => errorDetail.value && status.value !== 'connected'
);

const refreshStatus = async () => {
  try {
    const { data } = await BaileysAPI.getStatus(props.inboxId);
    pollFailures = 0;
    const previous = status.value;
    status.value = data.status || 'disconnected';
    pairingCode.value = data.pairingCode || '';
    errorDetail.value =
      [data.lastDisconnectReason, data.lastError].filter(Boolean).join(' — ') ||
      '';
    if (data.qr) {
      qrDataUrl.value = await QRCode.toDataURL(data.qr, { width: 264 });
    } else {
      qrDataUrl.value = '';
    }
    if (status.value === 'connected' && previous !== 'connected') {
      emit('connected');
    }
  } catch (error) {
    // A instância pode ainda não estar provisionada; tolera falhas
    // transitórias, mas depois de N seguidas assume serviço fora do ar.
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

const startPolling = () => {
  if (pollTimer) return;
  pollTimer = setInterval(refreshStatus, 3000);
};

const stopPolling = () => {
  if (!pollTimer) return;
  clearInterval(pollTimer);
  pollTimer = null;
};

watch(status, value => {
  if (POLLING_STATES.includes(value)) startPolling();
  else stopPolling();
});

onMounted(async () => {
  await refreshStatus();
  if (POLLING_STATES.includes(status.value)) startPolling();
});

onBeforeUnmount(stopPolling);
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex items-center gap-3">
      <span
        class="inline-flex items-center px-2 py-1 text-xs font-medium rounded-md"
        :class="statusBadgeClass"
      >
        {{ statusLabel }}
      </span>
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

    <div class="flex gap-2">
      <NextButton
        v-if="status !== 'connected'"
        :is-loading="isWorking"
        :label="t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.CONNECT_QR')"
        @click="connect(false)"
      />
      <NextButton
        v-if="status !== 'connected'"
        :is-loading="isWorking"
        faded
        :label="t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.CONNECT_CODE')"
        @click="connect(true)"
      />
      <NextButton
        v-if="status === 'connected'"
        :is-loading="isWorking"
        ruby
        faded
        :label="t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.LOGOUT')"
        @click="logout"
      />
    </div>
  </div>
</template>
