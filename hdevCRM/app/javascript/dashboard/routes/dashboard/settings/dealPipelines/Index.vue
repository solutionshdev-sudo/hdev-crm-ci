<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const { t } = useI18n();

const pipelines = useMapGetter('dealPipelines/getPipelines');
const editedPipeline = ref(null);

const startEditing = pipeline => {
  // Cópia profunda editável — só persiste no salvar.
  editedPipeline.value = JSON.parse(JSON.stringify(pipeline));
};

const addStage = () => {
  editedPipeline.value.stages.push({
    name: '',
    color: '#64748B',
    probability: 0,
    stage_type: 'open',
  });
};

const removeStage = index => {
  editedPipeline.value.stages.splice(index, 1);
};

const save = async () => {
  try {
    await store.dispatch('dealPipelines/update', {
      id: editedPipeline.value.id,
      name: editedPipeline.value.name,
      description: editedPipeline.value.description,
      stages: editedPipeline.value.stages,
    });
    await store.dispatch('dealPipelines/get');
    editedPipeline.value = null;
    useAlert(t('DEAL_PIPELINES.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(error.message || t('DEAL_PIPELINES.SAVE_ERROR'));
  }
};

onMounted(() => {
  store.dispatch('dealPipelines/get');
});
</script>

<template>
  <div class="flex flex-col w-full h-full gap-6 overflow-auto p-7">
    <BaseSettingsHeader
      :title="t('DEAL_PIPELINES.TITLE')"
      :description="t('DEAL_PIPELINES.DESCRIPTION')"
      feature-name="deal_pipelines"
    />

    <div
      v-for="pipeline in pipelines"
      :key="pipeline.id"
      class="p-4 border rounded-xl border-n-weak bg-n-solid-1"
    >
      <template v-if="editedPipeline?.id !== pipeline.id">
        <div class="flex items-center justify-between">
          <div class="flex flex-col">
            <span class="text-sm font-medium text-n-slate-12">
              {{ pipeline.name }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{ pipeline.stages.map(stage => stage.name).join(' → ') }}
            </span>
          </div>
          <NextButton
            faded
            slate
            :label="t('DEAL_PIPELINES.EDIT')"
            @click="startEditing(pipeline)"
          />
        </div>
      </template>

      <template v-else>
        <div class="flex flex-col gap-3">
          <label>
            {{ t('DEAL_PIPELINES.FORM.NAME') }}
            <input v-model="editedPipeline.name" type="text" />
          </label>

          <div class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('DEAL_PIPELINES.FORM.STAGES') }}
            </span>
            <div
              v-for="(stage, index) in editedPipeline.stages"
              :key="stage.id || `new-${index}`"
              class="flex items-center gap-2"
            >
              <input
                v-model="stage.color"
                type="color"
                class="!w-10 !h-9 !p-1 !mb-0 flex-shrink-0"
              />
              <input
                v-model="stage.name"
                type="text"
                class="!mb-0"
                :placeholder="t('DEAL_PIPELINES.FORM.STAGE_NAME')"
              />
              <select v-model="stage.stage_type" class="!mb-0 !w-40">
                <option value="open">
                  {{ t('DEAL_PIPELINES.FORM.STAGE_TYPES.OPEN') }}
                </option>
                <option value="won">
                  {{ t('DEAL_PIPELINES.FORM.STAGE_TYPES.WON') }}
                </option>
                <option value="lost">
                  {{ t('DEAL_PIPELINES.FORM.STAGE_TYPES.LOST') }}
                </option>
              </select>
              <NextButton
                ghost
                ruby
                icon="i-lucide-trash-2"
                @click="removeStage(index)"
              />
            </div>
            <div>
              <NextButton
                faded
                slate
                icon="i-lucide-plus"
                :label="t('DEAL_PIPELINES.FORM.ADD_STAGE')"
                @click="addStage"
              />
            </div>
          </div>

          <div class="flex justify-end gap-2">
            <NextButton
              faded
              slate
              :label="t('DEAL_PIPELINES.FORM.CANCEL')"
              @click="editedPipeline = null"
            />
            <NextButton
              solid
              blue
              :label="t('DEAL_PIPELINES.FORM.SAVE')"
              @click="save"
            />
          </div>
        </div>
      </template>
    </div>
  </div>
</template>
