<script setup>
import { ref, nextTick, onMounted } from 'vue';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

// components
import AuthSplitLayout from '../../components/Auth/AuthSplitLayout.vue';
import FormInput from '../../components/Form/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  authError: {
    type: String,
    default: '',
  },
  target: {
    type: String,
    default: 'web',
  },
});

const { t } = useI18n();

const credentials = ref({
  email: '',
});

const loginApi = ref({
  showLoading: false,
  hasErrored: false,
});

const handleAuthError = () => {
  if (!props.authError) {
    return;
  }

  const translatedMessage = t('LOGIN.SAML.API.ERROR_MESSAGE');
  useAlert(translatedMessage);
  loginApi.value.hasErrored = true;
};

const validations = {
  credentials: {
    email: {
      required,
      email,
    },
  },
};

const v$ = useVuelidate(validations, { credentials });

const csrfToken = ref('');

onMounted(async () => {
  csrfToken.value =
    document
      .querySelector('meta[name="csrf-token"]')
      ?.getAttribute('content') || '';

  await nextTick(handleAuthError);
});
</script>

<template>
  <AuthSplitLayout
    :headline="t('LOGIN.BRAND.HEADLINE')"
    :subtitle="t('LOGIN.BRAND.SUBTITLE')"
  >
    <section
      class="w-full p-8 shadow-lg rounded-xl bg-n-solid-1 outline outline-1 outline-n-weak"
      :class="{
        'animate-wiggle': loginApi.hasErrored,
      }"
    >
      <h2 class="text-2xl font-semibold text-n-slate-12">
        {{ t('LOGIN.SAML.TITLE') }}
      </h2>
      <p class="mt-2 mb-7 text-sm text-n-slate-11">
        {{ t('LOGIN.SAML.SUBTITLE') }}
      </p>
      <form class="space-y-5" method="POST" action="/api/v1/auth/saml_login">
        <FormInput
          v-model="credentials.email"
          name="email"
          type="text"
          :tabindex="1"
          required
          :label="t('LOGIN.SAML.WORK_EMAIL.LABEL')"
          :placeholder="t('LOGIN.SAML.WORK_EMAIL.PLACEHOLDER')"
          :has-error="v$.credentials.email.$error"
          @input="v$.credentials.email.$touch"
        />
        <input
          type="hidden"
          class="h-0"
          name="authenticity_token"
          :value="csrfToken"
        />
        <input type="hidden" class="h-0" name="target" :value="target" />
        <NextButton
          lg
          type="submit"
          class="w-full"
          :tabindex="2"
          :label="t('LOGIN.SAML.SUBMIT')"
          :disabled="loginApi.showLoading"
          :is-loading="loginApi.showLoading"
        />
      </form>
      <p class="mt-6 text-sm text-center text-n-slate-11">
        <router-link
          to="/app/login"
          class="font-medium text-n-blue-11 hover:text-n-blue-10"
        >
          {{ t('LOGIN.SAML.BACK_TO_LOGIN') }}
        </router-link>
      </p>
    </section>
  </AuthSplitLayout>
</template>
