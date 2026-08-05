<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';

const props = defineProps({
  identifier: {
    type: String,
    required: true,
  },
});

const { t } = useI18n();

const isSendingTest = ref(false);

// ponytail: sem endpoint helper dedicado pro público -- é uma URL só, feita
// aqui mesmo com o identifier que a tela já tem.
const leadCaptureUrl = computed(
  () =>
    `${window.location.origin}/public/api/v1/inboxes/${props.identifier}/leads`
);

// Os placeholders desse snippet (Nome, E-mail, Telefone, Mensagem, Enviar)
// ficam fixos em pt-BR de propósito: é HTML que o cliente final cola no site
// dele, não é texto da UI do dashboard -- não passa por I18n.
const formSnippet = computed(
  () => `<form action="${leadCaptureUrl.value}" method="post">
  <input name="nome" placeholder="Nome">
  <input name="email" type="email" placeholder="E-mail">
  <input name="telefone" placeholder="Telefone (+55...)">
  <textarea name="mensagem" placeholder="Mensagem"></textarea>
  <button type="submit">Enviar</button>
</form>`
);

const sendTestLead = async () => {
  isSendingTest.value = true;
  try {
    // Endpoint público (sem autenticação) -- fetch direto, nunca o axios do
    // dashboard, que anexaria os headers de sessão da conta via interceptor.
    // credentials: 'omit' pra garantir que o cookie de sessão do dashboard
    // não viaje pra esse endpoint público (same-origin mandaria por padrão).
    const response = await fetch(leadCaptureUrl.value, {
      method: 'POST',
      credentials: 'omit',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        nome: 'Lead de teste',
        mensagem: 'Lead de teste enviado pela tela de configurações.',
        external_id: `test-${Date.now()}`,
      }),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const data = await response.json();

    // A `mensagem` acima nunca vai em branco, e o backend
    // (leads_controller.rb#find_or_create_conversation) só devolve
    // conversation_id nulo quando `mensagem` está em branco -- não existe
    // branch sem conversa nesse fluxo de teste.
    useAlert(
      t('INBOX_MGMT.LEAD_CAPTURE.TEST_SUCCESS', {
        contactId: data.contact_id,
        conversationId: data.conversation_id,
      })
    );
  } catch (error) {
    useAlert(t('INBOX_MGMT.LEAD_CAPTURE.TEST_ERROR'));
  } finally {
    isSendingTest.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col gap-1">
    <div class="flex flex-col gap-1 mb-2">
      <label class="text-heading-3 text-n-slate-12">
        {{ t('INBOX_MGMT.LEAD_CAPTURE.TITLE') }}
      </label>
      <p class="text-label-small text-n-slate-11">
        {{ t('INBOX_MGMT.LEAD_CAPTURE.DESCRIPTION') }}
      </p>
    </div>

    <SettingsFieldSection :label="t('INBOX_MGMT.LEAD_CAPTURE.URL_LABEL')">
      <woot-code :script="leadCaptureUrl" lang="plaintext" />
    </SettingsFieldSection>

    <SettingsFieldSection
      :label="t('INBOX_MGMT.LEAD_CAPTURE.SNIPPET_LABEL')"
      :help-text="t('INBOX_MGMT.LEAD_CAPTURE.SNIPPET_HELP_TEXT')"
    >
      <woot-code :script="formSnippet" lang="html" />
    </SettingsFieldSection>

    <div class="mt-1">
      <NextButton
        type="button"
        slate
        outline
        data-test="lead-capture-test-button"
        :label="t('INBOX_MGMT.LEAD_CAPTURE.TEST_BUTTON')"
        :is-loading="isSendingTest"
        :disabled="isSendingTest"
        @click="sendTestLead"
      />
    </div>
  </div>
</template>
