<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  reasons: {
    type: Array,
    default: () => [],
  },
  // Rótulo de "perdido" do vocabulário do funil selecionado. Vazio quando o
  // funil não customizou essa chave — o título cai pro texto fixo de sempre.
  lostLabel: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['confirm', 'cancel']);

// Sentinela pro "Outro" no select — nunca deve colidir com um motivo real
// configurado pela conta.
const OTHER_VALUE = '__other__';

const { t } = useI18n();

const hasConfiguredReasons = computed(() => props.reasons.length > 0);

const title = computed(() =>
  props.lostLabel
    ? t('DEALS.LOST_REASON.TITLE_VOCAB', { lost: props.lostLabel })
    : t('DEALS.LOST_REASON.TITLE')
);

const selectedReason = ref(hasConfiguredReasons.value ? '' : OTHER_VALUE);
const customReason = ref('');
const error = ref('');

const showCustomInput = computed(
  () => !hasConfiguredReasons.value || selectedReason.value === OTHER_VALUE
);

const confirm = () => {
  const reason = (
    showCustomInput.value ? customReason.value : selectedReason.value
  ).trim();

  if (!reason) {
    error.value = t('DEALS.LOST_REASON.ERROR');
    return;
  }

  emit('confirm', reason);
};
</script>

<template>
  <div class="flex flex-col">
    <woot-modal-header :header-title="title" />
    <div class="flex flex-col gap-4 p-6">
      <label v-if="hasConfiguredReasons">
        {{ t('DEALS.LOST_REASON.SELECT_LABEL') }}
        <select v-model="selectedReason" data-test-id="lost-reason-select">
          <option value="" disabled>
            {{ t('DEALS.LOST_REASON.SELECT_PLACEHOLDER') }}
          </option>
          <option v-for="reason in reasons" :key="reason" :value="reason">
            {{ reason }}
          </option>
          <option :value="OTHER_VALUE">
            {{ t('DEALS.LOST_REASON.OTHER_OPTION') }}
          </option>
        </select>
      </label>

      <label v-if="showCustomInput">
        {{ t('DEALS.LOST_REASON.REASON_LABEL') }}
        <input
          v-model="customReason"
          type="text"
          data-test-id="lost-reason-input"
          :placeholder="t('DEALS.LOST_REASON.REASON_PLACEHOLDER')"
        />
      </label>

      <span v-if="error" class="text-xs text-n-ruby-9">{{ error }}</span>

      <div class="flex justify-end gap-2">
        <NextButton
          type="button"
          faded
          slate
          :label="t('DEALS.LOST_REASON.CANCEL')"
          data-test-id="lost-reason-cancel"
          @click="emit('cancel')"
        />
        <NextButton
          type="button"
          solid
          blue
          :label="t('DEALS.LOST_REASON.CONFIRM')"
          data-test-id="lost-reason-confirm"
          @click="confirm"
        />
      </div>
    </div>
  </div>
</template>
