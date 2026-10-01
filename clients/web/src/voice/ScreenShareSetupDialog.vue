<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type { ScreenProfile } from './livekit_gateway'
import { screenShareMaxBitrate, type ScreenFrameRate, type ScreenResolution } from './media_publishing'

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
const resolutions: readonly ScreenResolution[] = [720, 1080, 1440]
const frameRates: readonly ScreenFrameRate[] = [15, 30, 60]
const bitrate = computed(() => screenShareMaxBitrate(resolution.value, frameRate.value))
const bandwidthEstimate = computed(() => bitrate.value >= 1_000_000
  ? `≈ ${(bitrate.value / 1_000_000).toFixed(bitrate.value % 1_000_000 === 0 ? 0 : 1)} Мбит/с`
  : `≈ ${Math.round(bitrate.value / 1_000)} Кбит/с`)

function useProfile(profile: ScreenProfile): void {
  const values = profileValues(profile)
  if (!values) return
  resolution.value = values.resolution
  frameRate.value = values.frameRate
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
  emit('start', `P${resolution.value}_${frameRate.value}` as ScreenProfile)
}
</script>

<template>
  <dialog
    ref="dialog"
    class="screen-share-setup-dialog"
    aria-labelledby="screen-share-setup-title"
    aria-describedby="screen-share-setup-guidance"
    @cancel.prevent="emit('cancel')"
  >
    <header class="screen-share-setup__header">
      <span class="screen-share-setup__icon" aria-hidden="true">
        <svg viewBox="0 0 24 24"><path d="M3 4h18v13H3zM8 21h8m-4-4v4M8 12h3l2 2 4-5" /></svg>
      </span>
      <div class="screen-share-setup__title">
        <h2 id="screen-share-setup-title">Демонстрация экрана</h2>
        <p>Выберите источник и качество трансляции</p>
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
      <div id="screen-share-setup-guidance" class="screen-share-setup__notice" role="note">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3 21 7v5c0 5-3.7 8-9 10-5.3-2-9-5-9-10V7zm0 5v5m0 3h.01" /></svg>
        <p>{{ updating ? 'Качество и FPS изменятся в текущей трансляции без выбора экрана заново.' : 'После продолжения браузер покажет системный запрос на выбор экрана или окна. Вы сможете остановить трансляцию в любой момент.' }}</p>
      </div>

      <section class="screen-share-quality" aria-labelledby="screen-share-quality-title">
        <h3 id="screen-share-quality-title">
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h9m4 0h3M4 17h3m4 0h9M13 4v6M9 14v6" /></svg>
          Качество трансляции
        </h3>

        <fieldset class="screen-share-quality__row">
          <legend>Разрешение</legend>
          <div class="screen-share-quality__segments" role="radiogroup" aria-label="Разрешение трансляции">
            <label v-for="value in resolutions" :key="value" class="screen-share-quality__option">
              <input v-model="resolution" type="radio" name="screen-share-resolution" :value="value">
              <span>{{ value }}p</span>
            </label>
          </div>
        </fieldset>

        <fieldset class="screen-share-quality__row">
          <legend>Частота кадров</legend>
          <div class="screen-share-quality__segments" role="radiogroup" aria-label="Частота кадров трансляции">
            <label v-for="value in frameRates" :key="value" class="screen-share-quality__option">
              <input v-model="frameRate" type="radio" name="screen-share-frame-rate" :value="value">
              <span>{{ value }} FPS</span>
            </label>
          </div>
        </fieldset>

        <p class="screen-share-quality__hint">
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2 8a15 15 0 0 1 20 0M5 12a10 10 0 0 1 14 0m-11 4a5 5 0 0 1 8 0m-4 4h.01" /></svg>
          <span>Ориентировочно {{ bandwidthEstimate }}; более высокое качество увеличивает нагрузку на сеть и устройство.</span>
        </p>
      </section>
    </div>

    <footer class="screen-share-setup__footer">
      <button class="screen-share-setup__cancel" type="button" @click="emit('cancel')">Отмена</button>
      <button class="screen-share-setup__start" type="button" @click="start">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 4h18v13H3zM8 21h8m-4-4v4M12 8v6m-3-3 3-3 3 3" /></svg>
        {{ updating ? 'Применить качество' : 'Начать трансляцию' }}
      </button>
    </footer>
  </dialog>
</template>
