<script setup>
import { computed, ref } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PhoneNumberInput from 'dashboard/components-next/phonenumberinput/PhoneNumberInput.vue';
import BaileysSession from './whatsapp/BaileysSession.vue';

const store = useStore();
const router = useRouter();
const { t } = useI18n();

const currentUser = useMapGetter('getCurrentUser');
const uiFlags = useMapGetter('inboxes/getUIFlags');

const inboxName = ref('');
const phoneNumber = ref('');
const pairingMethod = ref('qr');
const proxyUrl = ref('');
const riskAccepted = ref(false);
const createdInbox = ref(null);

const rules = {
  inboxName: { required },
  phoneNumber: { required, isPhoneE164OrEmpty },
};
const v$ = useVuelidate(rules, { inboxName, phoneNumber });

const canSubmit = computed(() => riskAccepted.value && !uiFlags.value.isCreating);

const createChannel = async () => {
  v$.value.$touch();
  if (v$.value.$invalid || !riskAccepted.value) return;

  try {
    const inbox = await store.dispatch('inboxes/createChannel', {
      name: inboxName.value?.trim(),
      channel: {
        type: 'whatsapp',
        phone_number: phoneNumber.value,
        provider: 'baileys',
        provider_config: {
          pairing_method: pairingMethod.value,
          proxy_url: proxyUrl.value?.trim() || undefined,
          risk_accepted_at: new Date().toISOString(),
          risk_accepted_by: currentUser.value?.id,
        },
      },
    });
    createdInbox.value = inbox;
  } catch (error) {
    useAlert(
      error.message || t('INBOX_MGMT.ADD.WHATSAPP.API.ERROR_MESSAGE')
    );
  }
};

const finishWizard = () => {
  router.replace({
    name: 'settings_inboxes_add_agents',
    params: { page: 'new', inbox_id: createdInbox.value.id },
  });
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <!-- Aviso obrigatório: API não-oficial, risco de banimento, sem responsabilidade. -->
    <div class="p-4 border rounded-xl bg-n-ruby-3 border-n-ruby-6">
      <h3 class="mb-2 text-sm font-semibold text-n-ruby-11">
        {{ t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.WARNING.TITLE') }}
      </h3>
      <ul class="flex flex-col gap-1 pl-4 text-sm list-disc text-n-ruby-11">
        <li>{{ t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.WARNING.UNOFFICIAL') }}</li>
        <li>{{ t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.WARNING.BAN_RISK') }}</li>
        <li>{{ t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.WARNING.NO_LIABILITY') }}</li>
        <li>{{ t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.WARNING.RECOMMENDED') }}</li>
      </ul>
    </div>

    <form
      v-if="!createdInbox"
      class="flex flex-col flex-wrap mx-0"
      @submit.prevent="createChannel"
    >
      <div class="flex-grow-0 flex-shrink-0">
        <label :class="{ error: v$.inboxName.$error }">
          {{ t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.LABEL') }}
          <input
            v-model="inboxName"
            type="text"
            :placeholder="t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.PLACEHOLDER')"
            @blur="v$.inboxName.$touch"
          />
          <span v-if="v$.inboxName.$error" class="message">
            {{ t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.ERROR') }}
          </span>
        </label>
      </div>

      <div class="flex-grow-0 flex-shrink-0">
        <label :class="{ error: v$.phoneNumber.$error }">
          {{ t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.LABEL') }}
          <PhoneNumberInput
            v-model="phoneNumber"
            :placeholder="t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.PLACEHOLDER')"
          />
          <span v-if="v$.phoneNumber.$error" class="message">
            {{ t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.ERROR') }}
          </span>
        </label>
      </div>

      <div class="flex-grow-0 flex-shrink-0">
        <label>
          {{ t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.PAIRING_METHOD.LABEL') }}
          <select v-model="pairingMethod">
            <option value="qr">
              {{ t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.PAIRING_METHOD.QR') }}
            </option>
            <option value="code">
              {{ t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.PAIRING_METHOD.CODE') }}
            </option>
          </select>
        </label>
      </div>

      <div class="flex-grow-0 flex-shrink-0">
        <label>
          {{ t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.PROXY.LABEL') }}
          <input
            v-model="proxyUrl"
            type="text"
            :placeholder="t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.PROXY.PLACEHOLDER')"
          />
          <span class="text-xs text-n-slate-11">
            {{ t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.PROXY.HELP') }}
          </span>
        </label>
      </div>

      <label class="flex items-start gap-2 mt-4 text-sm text-n-slate-12">
        <input v-model="riskAccepted" type="checkbox" class="mt-1" />
        <span>{{ t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.WARNING.ACCEPT') }}</span>
      </label>

      <div class="w-full mt-4">
        <NextButton
          :disabled="!canSubmit"
          :is-loading="uiFlags.isCreating"
          type="submit"
          solid
          blue
          :label="t('INBOX_MGMT.ADD.WHATSAPP.SUBMIT_BUTTON')"
        />
      </div>
    </form>

    <div v-else class="flex flex-col gap-4">
      <p class="text-sm text-n-slate-11">
        {{ t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.CREATED_HELP') }}
      </p>
      <BaileysSession :inbox-id="createdInbox.id" />
      <div>
        <NextButton
          solid
          blue
          :label="t('INBOX_MGMT.ADD.WHATSAPP.BAILEYS.SESSION.CONTINUE')"
          @click="finishWizard"
        />
      </div>
    </div>
  </div>
</template>
