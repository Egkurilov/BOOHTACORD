<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type { ScreenProfile } from './livekit_gateway'
import type { ScreenFrameRate, ScreenResolution } from './media_publishing'
import { screenProfileMode, screenShareBandwidthEstimate } from './screen_profile_metadata/profile'
import ScreenShareQualityOptions from './ScreenShareQualityOptions.vue'

const props = defineProps<{ initialProfile: ScreenProfile; updating?: boolean }>()
const emit = defineEmits<{ cancel: []; start: [profile: ScreenProfile] }>()
const dialog = ref<HTMLDialogElement | null>(null)
const opener = ref<HTMLElement | null>(null)
function profileValues(profile: ScreenProfile): { resolution: ScreenResolution; frameRate: ScreenFrameRate } | null {
  const match = /^P(720|1080|1440)_(15|30|60)$/.exec(profile)
  if (!match) return null
  return { resolution: Number(match[1]) as ScreenResolution, frameRate: Number(match[2]) as ScreenFrameRate }
}
const initialValues = profileValues(props.initialProfile)
const resolution = ref<ScreenResolution>(initialValues?.resolution ?? 1080)
const frameRate = ref<ScreenFrameRate>(initialValues?.frameRate ?? 30)
const mode = ref<'motion' | 'text'>(screenProfileMode(props.initialProfile))
const allow1440p60 = false
const selectedProfile = computed(() => `P${resolution.value}_${frameRate.value}` as ScreenProfile)
const profileAllowed = computed(() => !(mode.value === 'motion' && resolution.value === 1440 && !allow1440p60))
const bandwidthEstimate = computed(() => screenShareBandwidthEstimate(selectedProfile.value))

function useProfile(profile: ScreenProfile): void {
  const values = profileValues(profile)
  if (!values) return
  resolution.value = values.resolution
  frameRate.value = values.frameRate
  mode.value = screenProfileMode(profile)
}

function selectMode(value: 'motion' | 'text'): void {
  mode.value = value
  frameRate.value = value === 'motion' ? 60 : 30
  if (value === 'motion' && resolution.value === 1440 && !allow1440p60) resolution.value = 1080
}

watch(() => props.initialProfile, useProfile)

onMounted(async () => {
  useProfile(props.initialProfile)
  opener.value = document.activeElement instanceof HTMLElement ? document.activeElement : null
  await nextTick()
  if (dialog.value && !dialog.value.open) dialog.value.showModal()
  await nextTick()
  dialog.value?.querySelector<HTMLElement>('[autofocus]')?.focus()
})

onBeforeUnmount(() => {
  if (dialog.value?.open) dialog.value.close()
  void nextTick(() => {
    if (opener.value?.isConnected) opener.value.focus()
  })
})

function start(): void {
  if (profileAllowed.value) emit('start', selectedProfile.value)
}
</script>

<template>
  <dialog
    ref="dialog"
    class="screen-share-setup-dialog" :class="{ 'screen-share-setup-dialog--updating': updating }"
    aria-labelledby="screen-share-setup-title"
    :aria-describedby="updating ? 'screen-share-setup-description' : 'screen-share-setup-guidance'"
    @cancel.prevent="emit('cancel')"
  >
    <header class="screen-share-setup__header">
      <span v-if="!updating" class="screen-share-setup__icon" aria-hidden="true">
        <svg viewBox="0 0 24 24"><path d="M3 4h18v13H3zM8 21h8m-4-4v4M8 12h3l2 2 4-5" /></svg>
      </span>
      <div class="screen-share-setup__title">
        <h2 id="screen-share-setup-title">{{ updating ? 'Качество трансляции' : 'Демонстрация экрана' }}</h2>
        <p :id="updating ? 'screen-share-setup-description' : undefined">{{ updating ? 'Изменения применятся к текущему показу.' : 'Выберите источник и качество трансляции' }}</p>
      </div>
      <button
        class="screen-share-setup__close"
        type="button"
        aria-label="Закрыть"
        title="Закрыть"
        autofocus
        @click="emit('cancel')"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18" /></svg>
      </button>
    </header>

    <div class="screen-share-setup__body">
      <div v-if="!updating" id="screen-share-setup-guidance" class="screen-share-setup__notice" role="note">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3 21 7v5c0 5-3.7 8-9 10-5.3-2-9-5-9-10V7zm0 5v5m0 3h.01" /></svg>
        <p>{{ updating ? 'Качество и FPS изменятся в текущей трансляции без выбора экрана заново.' : 'После продолжения браузер покажет системный запрос на выбор экрана или окна. Вы сможете остановить трансляцию в любой момент.' }}</p>
      </div>

      <section class="screen-share-quality" aria-labelledby="screen-share-quality-title">
        <h3 id="screen-share-quality-title" :class="{ 'gc-sr-only': updating }">
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h9m4 0h3M4 17h3m4 0h9M13 4v6M9 14v6" /></svg>
          Качество трансляции
        </h3>

        <ScreenShareQualityOptions v-model:resolution="resolution" v-model:frame-rate="frameRate" :mode="mode" :allow-1440p60="allow1440p60" @update:mode="selectMode" />

        <p v-if="!updating" class="screen-share-quality__hint">
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2 8a15 15 0 0 1 20 0M5 12a10 10 0 0 1 14 0m-11 4a5 5 0 0 1 8 0m-4 4h.01" /></svg>
          <span>Суммарный лимит двух слоёв — {{ bandwidthEstimate }}; это не гарантированный сетевой расход.</span>
        </p>
        <p v-else class="screen-share-quality__warning"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7h.01"/></svg><span>При ухудшении сети качество может временно снижаться. Приоритет — голос.</span></p>
      </section>
    </div>

    <footer class="screen-share-setup__footer">
      <button class="screen-share-setup__cancel" type="button" @click="emit('cancel')">Отмена</button>
      <button class="screen-share-setup__start" type="button" :disabled="!profileAllowed" @click="start">
        <svg v-if="!updating" viewBox="0 0 24 24" aria-hidden="true"><path d="M3 4h18v13H3zM8 21h8m-4-4v4M12 8v6m-3-3 3-3 3 3" /></svg>
        {{ updating ? 'Применить' : 'Начать трансляцию' }}
      </button>
    </footer>
  </dialog>
</template>
