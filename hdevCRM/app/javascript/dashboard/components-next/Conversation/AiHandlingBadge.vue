<script setup>
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
</script>

<template>
  <span
    class="inline-flex items-center justify-center gap-1 h-5 px-1.5 rounded-md text-label-small shrink-0 bg-n-violet-3 text-n-violet-11"
  >
    <Icon icon="i-lucide-sparkles" class="size-3 flex-shrink-0" />
    <span class="truncate">{{ t('CONVERSATION.AI_HANDLING_BADGE') }}</span>
  </span>
</template>
