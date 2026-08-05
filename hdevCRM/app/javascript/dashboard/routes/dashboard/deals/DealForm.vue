<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';
import ContactAPI from 'dashboard/api/contacts';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  pipeline: {
    type: Object,
    required: true,
  },
  deal: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();
const agents = useMapGetter('agents/getAgents');

const title = ref('');
const value = ref(0);
const stageId = ref(null);
const assigneeId = ref(null);
const expectedCloseOn = ref('');
const description = ref('');

const contactQuery = ref('');
const contactResults = ref([]);
const selectedContact = ref(null);
let searchTimer = null;

const isEditing = computed(() => Boolean(props.deal));

const rules = {
  title: { required },
};
const v$ = useVuelidate(rules, { title });

const searchContacts = query => {
  clearTimeout(searchTimer);
  if (!query || query.length < 2) {
    contactResults.value = [];
    return;
  }
  searchTimer = setTimeout(async () => {
    try {
      const { data } = await ContactAPI.search(query, 1, 'name');
      contactResults.value = data.payload.slice(0, 8);
    } catch (error) {
      contactResults.value = [];
    }
  }, 300);
};

watch(contactQuery, searchContacts);

const selectContact = contact => {
  selectedContact.value = contact;
  contactQuery.value = contact.name;
  contactResults.value = [];
};

const submit = () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;
  if (!isEditing.value && !selectedContact.value) return;

  emit('submit', {
    title: title.value.trim(),
    value: value.value || 0,
    deal_stage_id: stageId.value,
    assignee_id: assigneeId.value || null,
    expected_close_on: expectedCloseOn.value || null,
    description: description.value || null,
    ...(isEditing.value
      ? {}
      : {
          contact_id: selectedContact.value.id,
          deal_pipeline_id: props.pipeline.id,
        }),
  });
};

onMounted(() => {
  if (props.deal) {
    title.value = props.deal.title;
    value.value = Number(props.deal.value || 0);
    stageId.value = props.deal.deal_stage_id;
    assigneeId.value = props.deal.assignee?.id || null;
    expectedCloseOn.value = props.deal.expected_close_on || '';
    description.value = props.deal.description || '';
    selectedContact.value = props.deal.contact;
    contactQuery.value = props.deal.contact?.name || '';
  } else {
    stageId.value = props.pipeline.stages?.[0]?.id;
  }
});
</script>

<template>
  <form class="flex flex-col gap-4 p-6" @submit.prevent="submit">
    <label :class="{ error: v$.title.$error }">
      {{ t('DEALS.FORM.TITLE.LABEL') }}
      <input
        v-model="title"
        type="text"
        :placeholder="t('DEALS.FORM.TITLE.PLACEHOLDER')"
        @blur="v$.title.$touch"
      />
      <span v-if="v$.title.$error" class="message">
        {{ t('DEALS.FORM.TITLE.ERROR') }}
      </span>
    </label>

    <label v-if="!isEditing" class="relative">
      {{ t('DEALS.FORM.CONTACT.LABEL') }}
      <input
        v-model="contactQuery"
        type="text"
        :placeholder="t('DEALS.FORM.CONTACT.PLACEHOLDER')"
        autocomplete="off"
      />
      <div
        v-if="contactResults.length"
        class="absolute z-20 w-full mt-1 overflow-hidden border shadow-lg rounded-xl bg-n-solid-1 border-n-weak"
      >
        <button
          v-for="contact in contactResults"
          :key="contact.id"
          type="button"
          class="flex flex-col w-full px-3 py-2 text-left hover:bg-n-alpha-1"
          @click="selectContact(contact)"
        >
          <span class="text-sm text-n-slate-12">{{ contact.name }}</span>
          <span class="text-xs text-n-slate-11">
            {{ contact.phone_number || contact.email }}
          </span>
        </button>
      </div>
    </label>

    <div class="grid grid-cols-2 gap-4">
      <label>
        {{ t('DEALS.FORM.VALUE.LABEL') }}
        <input v-model.number="value" type="number" min="0" step="0.01" />
      </label>
      <label>
        {{ t('DEALS.FORM.STAGE.LABEL') }}
        <select v-model="stageId">
          <option
            v-for="stage in pipeline.stages"
            :key="stage.id"
            :value="stage.id"
          >
            {{ stage.name }}
          </option>
        </select>
      </label>
    </div>

    <div class="grid grid-cols-2 gap-4">
      <label>
        {{ t('DEALS.FORM.ASSIGNEE.LABEL') }}
        <select v-model="assigneeId">
          <option :value="null">
            {{ t('DEALS.FORM.ASSIGNEE.NONE') }}
          </option>
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
      </label>
      <label>
        {{ t('DEALS.FORM.EXPECTED_CLOSE.LABEL') }}
        <input v-model="expectedCloseOn" type="date" />
      </label>
    </div>

    <label>
      {{ t('DEALS.FORM.DESCRIPTION.LABEL') }}
      <textarea v-model="description" rows="3" />
    </label>

    <div class="flex justify-end gap-2">
      <NextButton
        type="button"
        faded
        slate
        :label="t('DEALS.FORM.CANCEL')"
        @click="emit('cancel')"
      />
      <NextButton
        type="submit"
        solid
        blue
        :label="isEditing ? t('DEALS.FORM.UPDATE') : t('DEALS.FORM.CREATE')"
      />
    </div>
  </form>
</template>
