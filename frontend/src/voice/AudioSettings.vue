<script setup lang="ts">
import type { AudioDevice, AudioDeviceKind } from './audio_devices'
import type { AudioSettingsState } from './audio_settings_store'
import type { VoiceActivationMode } from './activation_store'
import { audioProcessingStatus, type AudioProcessingDiagnostics } from './audio_processing_diagnostics'
import { capturePttAssignment } from './ptt_key_capture'
import type { AudioProcessingOptions } from './livekit_gateway'
import { onBeforeUnmount, onMounted, ref } from 'vue'

const props = defineProps<{
  activationError: string | null
  activationMode: VoiceActivationMode
  processingDiagnostics: AudioProcessingDiagnostics
  devices: { inputs: AudioDevice[]; outputs: AudioDevice[] }
  error: string | null
  pttKey: string | null
  processing: AudioProcessingOptions
  state: AudioSettingsState
}>()

const emit = defineEmits<{
  load: []
  select: [kind: AudioDeviceKind, deviceId: string]
  setActivation: [mode: VoiceActivationMode]
  setProcessing: [processing: AudioProcessingOptions]
  setPttKey: [key: string]
}>()
const recordingPttKey = ref(false)
const entry = ref<HTMLElement | null>(null)
let focusFrame: number | null = null
onMounted(() => { focusFrame = window.requestAnimationFrame(() => entry.value?.focus()) })
onBeforeUnmount(() => { if (focusFrame !== null) window.cancelAnimationFrame(focusFrame) })

function capturePttKey(event: KeyboardEvent): void {
  if (!recordingPttKey.value) return
  capturePttAssignment(event, () => { recordingPttKey.value = false }, (code) => emit('setPttKey', code))
}

function setProcessing(key: keyof AudioProcessingOptions, event: Event): void {
  emit('setProcessing', { ...props.processing, [key]: (event.target as HTMLInputElement).checked })
}
</script>

<template>
  <section ref="entry" class="audio-settings" aria-label="Настройки аудио" tabindex="-1">
    <button class="voice-leave" type="button" :disabled="state === 'LOADING'" @click="emit('load')">
      {{ state === 'LOADING' ? 'Ищем устройства…' : 'Настройки аудио' }}
    </button>
    <p v-if="error" class="state state-error" role="alert">{{ error }}</p>
    <label>
      Активация микрофона
      <select :value="activationMode" @change="emit('setActivation', ($event.target as HTMLSelectElement).value as VoiceActivationMode)">
        <option value="VAD">Голосовая активность</option>
        <option value="PTT">Push-to-talk</option>
      </select>
    </label>
    <button class="voice-leave" type="button" @click="recordingPttKey = true" @keydown="capturePttKey">
      {{ recordingPttKey ? 'Нажмите клавишу…' : pttKey ? `PTT: ${pttKey}` : 'Назначить PTT-клавишу' }}
    </button>
    <p v-if="activationError" class="state state-error" role="alert">{{ activationError }}</p>
    <fieldset>
      <legend>Обработка микрофона браузером</legend>
      <label><input type="checkbox" :checked="processing.autoGainControl" @change="setProcessing('autoGainControl', $event)"> Автоматическая регулировка усиления</label>
      <p class="state" aria-live="polite">AGC — {{ audioProcessingStatus(processingDiagnostics.autoGainControl) }}</p>
      <label><input type="checkbox" :checked="processing.echoCancellation" @change="setProcessing('echoCancellation', $event)"> Подавление эха</label>
      <p class="state" aria-live="polite">Эхоподавление — {{ audioProcessingStatus(processingDiagnostics.echoCancellation) }}</p>
      <label><input type="checkbox" :checked="processing.noiseSuppression" @change="setProcessing('noiseSuppression', $event)"> Подавление шума</label>
      <p class="state" aria-live="polite">Шумоподавление — {{ audioProcessingStatus(processingDiagnostics.noiseSuppression) }}</p>
    </fieldset>
    <template v-if="state === 'READY'">
      <label>
        Микрофон
        <select @change="emit('select', 'audioinput', ($event.target as HTMLSelectElement).value)">
          <option v-for="device in devices.inputs" :key="device.id" :value="device.id">{{ device.label }}</option>
        </select>
      </label>
      <label>
        Динамик
        <select @change="emit('select', 'audiooutput', ($event.target as HTMLSelectElement).value)">
          <option v-for="device in devices.outputs" :key="device.id" :value="device.id">{{ device.label }}</option>
        </select>
      </label>
    </template>
  </section>
</template>
