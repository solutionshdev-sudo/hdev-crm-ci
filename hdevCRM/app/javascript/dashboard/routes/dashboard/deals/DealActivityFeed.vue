<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import DealsAPI from 'dashboard/api/deals';
import { dynamicTime } from 'shared/helpers/timeHelper';

const props = defineProps({
  dealId: {
    type: [String, Number],
    required: true,
  },
});

const { t } = useI18n();
const activities = ref([]);
const isLoading = ref(true);

const label = activity => {
  const key = `DEALS.ACTIVITY.${activity.activity_type.toUpperCase()}`;
  return t(key, {
    from: activity.from_stage || '',
    to: activity.to_stage || '',
    user: activity.user?.name || t('DEALS.ACTIVITY.SYSTEM'),
  });
};

onMounted(async () => {
  try {
    const { data } = await DealsAPI.getActivities(props.dealId);
    activities.value = data.payload;
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <div class="flex flex-col gap-3">
    <h4 class="text-sm font-medium text-n-slate-12">
      {{ t('DEALS.ACTIVITY.TITLE') }}
    </h4>
    <p v-if="isLoading" class="text-sm text-n-slate-11">
      {{ t('DEALS.ACTIVITY.LOADING') }}
    </p>
    <ul v-else class="flex flex-col gap-2">
      <li
        v-for="activity in activities"
        :key="activity.id"
        class="flex items-baseline justify-between gap-2 text-sm"
      >
        <span class="text-n-slate-11">{{ label(activity) }}</span>
        <span class="flex-shrink-0 text-xs text-n-slate-10">
          {{ dynamicTime(activity.created_at) }}
        </span>
      </li>
    </ul>
  </div>
</template>
