<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import AgenciesAPI from 'dashboard/api/agencies';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();

const loaded = ref(false);
const agency = ref(null);
const accounts = ref([]);
const usage = ref(null);
const isSavingBranding = ref(false);
const isCreating = ref(false);
const showNewAccountForm = ref(false);

const branding = reactive({
  name: '',
  brand_name: '',
  installation_name: '',
  primary_color: '#00875A',
  custom_domain: '',
  brand_url: '',
  terms_url: '',
  privacy_url: '',
});

const newAccount = reactive({
  account_name: '',
  user_full_name: '',
  email: '',
  password: '',
});

const usageByAccount = computed(() => {
  const map = {};
  (usage.value?.per_account || []).forEach(row => {
    map[row.account_id] = row;
  });
  return map;
});

const totalCost = computed(() => {
  const cost = usage.value?.summary?.cost;
  if (cost === undefined || cost === null) return '—';
  return `US$ ${Number(cost).toFixed(4)}`;
});

const syncBrandingForm = () => {
  branding.name = agency.value.name || '';
  branding.brand_name = agency.value.brand_name || '';
  branding.installation_name = agency.value.installation_name || '';
  branding.primary_color = agency.value.primary_color || '#00875A';
  branding.custom_domain = agency.value.custom_domain || '';
  branding.brand_url = agency.value.brand_url || '';
  branding.terms_url = agency.value.terms_url || '';
  branding.privacy_url = agency.value.privacy_url || '';
};

const fetchAgencyData = async () => {
  const [{ data: accountsData }, { data: usageData }] = await Promise.all([
    AgenciesAPI.getAccounts(agency.value.id),
    AgenciesAPI.getAiUsage(agency.value.id),
  ]);
  accounts.value = accountsData;
  usage.value = usageData;
};

const fetchAll = async () => {
  try {
    const { data: agenciesData } = await AgenciesAPI.list();
    if (agenciesData.length) {
      [agency.value] = agenciesData;
      syncBrandingForm();
      await fetchAgencyData();
    }
  } catch {
    useAlert(t('AGENCY_SETTINGS.API.FETCH_ERROR'));
  } finally {
    loaded.value = true;
  }
};

const saveBranding = async () => {
  isSavingBranding.value = true;
  try {
    const { data } = await AgenciesAPI.update(agency.value.id, { ...branding });
    agency.value = data;
    syncBrandingForm();
    useAlert(t('AGENCY_SETTINGS.API.BRANDING_SUCCESS'));
  } catch {
    useAlert(t('AGENCY_SETTINGS.API.BRANDING_ERROR'));
  } finally {
    isSavingBranding.value = false;
  }
};

const createAccount = async () => {
  isCreating.value = true;
  try {
    await AgenciesAPI.createAccount(agency.value.id, { ...newAccount });
    useAlert(t('AGENCY_SETTINGS.API.ACCOUNT_SUCCESS'));
    Object.keys(newAccount).forEach(key => {
      newAccount[key] = '';
    });
    showNewAccountForm.value = false;
    await fetchAgencyData();
  } catch {
    useAlert(t('AGENCY_SETTINGS.API.ACCOUNT_ERROR'));
  } finally {
    isCreating.value = false;
  }
};

onMounted(fetchAll);
</script>

<template>
  <div class="flex flex-col w-full max-w-4xl gap-8 p-8 overflow-auto">
    <div class="flex flex-col gap-1">
      <h1 class="text-2xl font-medium text-n-slate-12">
        {{ t('AGENCY_SETTINGS.HEADER') }}
      </h1>
      <p class="text-sm text-n-slate-11">
        {{ t('AGENCY_SETTINGS.DESCRIPTION') }}
      </p>
    </div>

    <div
      v-if="loaded && !agency"
      class="p-6 text-sm border rounded-xl border-n-weak text-n-slate-11"
    >
      {{ t('AGENCY_SETTINGS.EMPTY_STATE') }}
    </div>

    <template v-else-if="agency">
      <div class="grid grid-cols-3 gap-4">
        <div class="flex flex-col gap-1 p-4 border rounded-xl border-n-weak">
          <span class="text-xs text-n-slate-11">
            {{ t('AGENCY_SETTINGS.STATS.ACCOUNTS') }}
          </span>
          <span class="text-lg font-medium text-n-slate-12">
            {{ accounts.length }}
          </span>
        </div>
        <div class="flex flex-col gap-1 p-4 border rounded-xl border-n-weak">
          <span class="text-xs text-n-slate-11">
            {{ t('AGENCY_SETTINGS.STATS.TOKENS') }}
          </span>
          <span class="text-lg font-medium text-n-slate-12">
            {{ (usage?.summary?.total_tokens || 0).toLocaleString() }}
          </span>
        </div>
        <div class="flex flex-col gap-1 p-4 border rounded-xl border-n-weak">
          <span class="text-xs text-n-slate-11">
            {{ t('AGENCY_SETTINGS.STATS.COST') }}
          </span>
          <span class="text-lg font-medium text-n-slate-12">
            {{ totalCost }}
          </span>
        </div>
      </div>

      <section class="flex flex-col gap-4">
        <h2 class="text-lg font-medium text-n-slate-12">
          {{ t('AGENCY_SETTINGS.BRANDING.TITLE') }}
        </h2>
        <div class="grid grid-cols-2 gap-4">
          <label class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('AGENCY_SETTINGS.BRANDING.NAME') }}
            </span>
            <input
              v-model="branding.name"
              class="w-full px-3 py-2 text-sm border rounded-lg outline-none border-n-weak bg-n-background text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('AGENCY_SETTINGS.BRANDING.BRAND_NAME') }}
            </span>
            <input
              v-model="branding.brand_name"
              class="w-full px-3 py-2 text-sm border rounded-lg outline-none border-n-weak bg-n-background text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('AGENCY_SETTINGS.BRANDING.INSTALLATION_NAME') }}
            </span>
            <input
              v-model="branding.installation_name"
              class="w-full px-3 py-2 text-sm border rounded-lg outline-none border-n-weak bg-n-background text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('AGENCY_SETTINGS.BRANDING.PRIMARY_COLOR') }}
            </span>
            <div class="flex items-center gap-2">
              <input
                v-model="branding.primary_color"
                type="color"
                class="w-10 h-9 p-0 border rounded-lg cursor-pointer border-n-weak bg-n-background"
              />
              <input
                v-model="branding.primary_color"
                class="flex-1 px-3 py-2 text-sm border rounded-lg outline-none border-n-weak bg-n-background text-n-slate-12"
              />
            </div>
          </label>
          <label class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('AGENCY_SETTINGS.BRANDING.CUSTOM_DOMAIN') }}
            </span>
            <input
              v-model="branding.custom_domain"
              :placeholder="
                t('AGENCY_SETTINGS.BRANDING.CUSTOM_DOMAIN_PLACEHOLDER')
              "
              class="w-full px-3 py-2 text-sm border rounded-lg outline-none border-n-weak bg-n-background text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('AGENCY_SETTINGS.BRANDING.BRAND_URL') }}
            </span>
            <input
              v-model="branding.brand_url"
              class="w-full px-3 py-2 text-sm border rounded-lg outline-none border-n-weak bg-n-background text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('AGENCY_SETTINGS.BRANDING.TERMS_URL') }}
            </span>
            <input
              v-model="branding.terms_url"
              class="w-full px-3 py-2 text-sm border rounded-lg outline-none border-n-weak bg-n-background text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('AGENCY_SETTINGS.BRANDING.PRIVACY_URL') }}
            </span>
            <input
              v-model="branding.privacy_url"
              class="w-full px-3 py-2 text-sm border rounded-lg outline-none border-n-weak bg-n-background text-n-slate-12"
            />
          </label>
        </div>
        <p class="text-xs text-n-slate-11">
          {{ t('AGENCY_SETTINGS.BRANDING.DOMAIN_NOTE') }}
        </p>
        <div>
          <NextButton
            :label="t('AGENCY_SETTINGS.BRANDING.SAVE')"
            :is-loading="isSavingBranding"
            @click="saveBranding"
          />
        </div>
      </section>

      <section class="flex flex-col gap-4">
        <div class="flex items-center justify-between">
          <h2 class="text-lg font-medium text-n-slate-12">
            {{ t('AGENCY_SETTINGS.ACCOUNTS.TITLE') }}
          </h2>
          <NextButton
            :label="t('AGENCY_SETTINGS.ACCOUNTS.NEW')"
            slate
            @click="showNewAccountForm = !showNewAccountForm"
          />
        </div>

        <div
          v-if="showNewAccountForm"
          class="flex flex-col gap-4 p-4 border rounded-xl border-n-weak"
        >
          <div class="grid grid-cols-2 gap-4">
            <label class="flex flex-col gap-2">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('AGENCY_SETTINGS.ACCOUNTS.FORM.ACCOUNT_NAME') }}
              </span>
              <input
                v-model="newAccount.account_name"
                class="w-full px-3 py-2 text-sm border rounded-lg outline-none border-n-weak bg-n-background text-n-slate-12"
              />
            </label>
            <label class="flex flex-col gap-2">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('AGENCY_SETTINGS.ACCOUNTS.FORM.USER_NAME') }}
              </span>
              <input
                v-model="newAccount.user_full_name"
                class="w-full px-3 py-2 text-sm border rounded-lg outline-none border-n-weak bg-n-background text-n-slate-12"
              />
            </label>
            <label class="flex flex-col gap-2">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('AGENCY_SETTINGS.ACCOUNTS.FORM.EMAIL') }}
              </span>
              <input
                v-model="newAccount.email"
                type="email"
                class="w-full px-3 py-2 text-sm border rounded-lg outline-none border-n-weak bg-n-background text-n-slate-12"
              />
            </label>
            <label class="flex flex-col gap-2">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('AGENCY_SETTINGS.ACCOUNTS.FORM.PASSWORD') }}
              </span>
              <input
                v-model="newAccount.password"
                type="password"
                class="w-full px-3 py-2 text-sm border rounded-lg outline-none border-n-weak bg-n-background text-n-slate-12"
              />
            </label>
          </div>
          <div>
            <NextButton
              :label="t('AGENCY_SETTINGS.ACCOUNTS.FORM.CREATE')"
              :is-loading="isCreating"
              @click="createAccount"
            />
          </div>
        </div>

        <div class="overflow-hidden border rounded-xl border-n-weak">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left border-b border-n-weak text-n-slate-11">
                <th class="px-4 py-3 font-medium">
                  {{ t('AGENCY_SETTINGS.ACCOUNTS.TABLE.NAME') }}
                </th>
                <th class="px-4 py-3 font-medium">
                  {{ t('AGENCY_SETTINGS.ACCOUNTS.TABLE.STATUS') }}
                </th>
                <th class="px-4 py-3 font-medium">
                  {{ t('AGENCY_SETTINGS.ACCOUNTS.TABLE.TOKENS') }}
                </th>
                <th class="px-4 py-3 font-medium">
                  {{ t('AGENCY_SETTINGS.ACCOUNTS.TABLE.COST') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="clientAccount in accounts"
                :key="clientAccount.id"
                class="border-b border-n-weak last:border-b-0 text-n-slate-12"
              >
                <td class="px-4 py-3">{{ clientAccount.name }}</td>
                <td class="px-4 py-3">{{ clientAccount.status }}</td>
                <td class="px-4 py-3">
                  {{
                    (
                      usageByAccount[clientAccount.id]?.total_tokens || 0
                    ).toLocaleString()
                  }}
                </td>
                <td class="px-4 py-3">
                  US$
                  {{
                    Number(usageByAccount[clientAccount.id]?.cost || 0).toFixed(
                      4
                    )
                  }}
                </td>
              </tr>
              <tr v-if="!accounts.length">
                <td colspan="4" class="px-4 py-6 text-center text-n-slate-11">
                  {{ t('AGENCY_SETTINGS.ACCOUNTS.EMPTY') }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </template>
  </div>
</template>
