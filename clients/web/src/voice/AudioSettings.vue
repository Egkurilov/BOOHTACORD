<script setup lang="ts">
import type { AudioDevice, AudioDeviceKind } from './audio_devices'
import type { AudioSettingsState } from './audio_settings_store'
import type { VoiceActivationMode } from './activation_store'
import { audioProcessingStatus, noiseSuppressionModeLabel, noiseSuppressionFallbackLabel, type AudioProcessingDiagnostics } from './audio_processing_diagnostics'
import { capturePttAssignment } from './ptt_key_capture'
import { rnnoiseReleaseEnabled } from './noise_suppression/capabilities'
import type { NoiseSuppressionMode } from './noise_suppression/types'
import type { AudioProcessingOptions } from './livekit_gateway'
import AudioDeviceCheck from './AudioDeviceCheck.vue'
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'

const props = defineProps<{
  activationError: string | null
  activationMode: VoiceActivationMode
  processingDiagnostics: AudioProcessingDiagnostics
  devices: { inputs: AudioDevice[]; outputs: AudioDevice[] }
  error: string | null
  pttKey: string | null
  processing: AudioProcessingOptions
  state: AudioSettingsState
  connected: boolean
  microphoneTrack?: MediaStreamTrack
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
const selectedInput = ref('default')
const selectedOutput = ref('default')
const deviceWarning = ref('')
let focusFrame: number | null = null
function refreshDevices(): void { emit('load') }
onMounted(() => { focusFrame = window.requestAnimationFrame(() => entry.value?.focus()); refreshDevices(); navigator.mediaDevices?.addEventListener?.('devicechange', refreshDevices) })
onBeforeUnmount(() => { if (focusFrame !== null) window.cancelAnimationFrame(focusFrame); navigator.mediaDevices?.removeEventListener?.('devicechange', refreshDevices) })
watch(() => props.devices, ({ inputs, outputs }) => {
  if (inputs.length && !inputs.some(({ id }) => id === selectedInput.value)) {
    if (selectedInput.value !== 'default') deviceWarning.value = 'Выбранный микрофон отключён. Выберите доступное устройство и проверьте звук.'
    selectedInput.value = inputs[0].id
  }
  if (outputs.length && !outputs.some(({ id }) => id === selectedOutput.value)) {
    if (selectedOutput.value !== 'default') deviceWarning.value = 'Выбранный динамик отключён. Выберите доступное устройство и проверьте звук.'
    selectedOutput.value = outputs[0].id
  }
}, { immediate: true })

function choose(kind: AudioDeviceKind, event: Event): void {
  const id = (event.target as HTMLSelectElement).value
  if (kind === 'audioinput') selectedInput.value = id
  else selectedOutput.value = id
  deviceWarning.value = ''
  if (props.connected) emit('select', kind, id)
}

function capturePttKey(event: KeyboardEvent): void {
  if (!recordingPttKey.value) return
  capturePttAssignment(event, () => { recordingPttKey.value = false }, (code) => emit('setPttKey', code))
}

function setProcessing(key: 'autoGainControl' | 'echoCancellation', event: Event): void {
  emit('setProcessing', { ...props.processing, [key]: (event.target as HTMLInputElement).checked })
}
</script>

<template>
  <section ref="entry" class="audio-settings" aria-label="Настройки аудио" tabindex="-1">
    <button class="voice-leave" type="button" :disabled="state === 'LOADING'" @click="emit('load')">
      {{ state === 'LOADING' ? 'Ищем устройства…' : 'Настройки аудио' }}
    </button>
    <p v-if="error" class="state state-error" role="alert">{{ error }}</p>
    <p v-if="deviceWarning" class="state state-error" role="status">{{ deviceWarning }}</p>
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
      <legend>Обработка микрофона</legend>
      <label><input type="checkbox" :checked="processing.autoGainControl" @change="setProcessing('autoGainControl', $event)"> Автоматическая регулировка усиления</label>
      <p class="state" aria-live="polite">AGC — {{ audioProcessingStatus(processingDiagnostics.autoGainControl) }}</p>
      <label><input type="checkbox" :checked="processing.echoCancellation" @change="setProcessing('echoCancellation', $event)"> Подавление эха</label>
      <p class="state" aria-live="polite">Эхоподавление — {{ audioProcessingStatus(processingDiagnostics.echoCancellation) }}</p>
      <label>Шумоподавление
        <select :value="processing.noiseSuppressionMode" @change="emit('setProcessing', { ...processing, noiseSuppressionMode: ($event.target as HTMLSelectElement).value as NoiseSuppressionMode })">
          <option value="off">Выключено</option>
          <option value="browser">Стандартное — браузер</option>
          <option v-if="rnnoiseReleaseEnabled()" value="rnnoise">RNNoise — экспериментальное</option>
          <option v-if="!rnnoiseReleaseEnabled() && processing.noiseSuppressionMode === 'rnnoise'" value="rnnoise" disabled>RNNoise — недоступен в этой сборке</option>
        </select>
      </label>
      <p class="state" aria-live="polite">Выбрано: {{ noiseSuppressionModeLabel(processing.noiseSuppressionMode) }}. Работает: {{ noiseSuppressionModeLabel(processingDiagnostics.noiseSuppressionRuntime.effectiveMode) }}.</p>
      <p v-if="processingDiagnostics.noiseSuppressionRuntime.fallbackReason" class="state" role="status">Причина: {{ noiseSuppressionFallbackLabel(processingDiagnostics.noiseSuppressionRuntime.fallbackReason) }}.</p>
      <p v-if="processingDiagnostics.noiseSuppressionRuntime.status === 'initializing'" class="state" role="status">Подготавливаем фильтр…</p>
      <p v-if="processingDiagnostics.noiseSuppressionRuntime.status === 'error'" class="state state-error" role="alert">Ошибка обработки микрофона. Отправка звука выключена.</p>
      <details><summary>Диагностика обработки</summary>
        <p>Browser NS — {{ audioProcessingStatus(processingDiagnostics.noiseSuppression) }}</p>
        <p>Источник capture: {{ processingDiagnostics.captureSource === 'original-microphone' ? 'исходный микрофон' : 'недоступен' }}. Статус: {{ processingDiagnostics.noiseSuppressionRuntime.status }}.</p>
        <p v-if="processingDiagnostics.noiseSuppressionRuntime.modelId">Модель: {{ processingDiagnostics.noiseSuppressionRuntime.modelId }}.</p>
        <p>Частота исходного capture: {{ processingDiagnostics.noiseSuppressionRuntime.captureSampleRate === undefined ? 'недоступна' : `${processingDiagnostics.noiseSuppressionRuntime.captureSampleRate} Гц` }}.</p>
        <p v-if="processingDiagnostics.noiseSuppressionRuntime.initDurationMs !== undefined">Подготовка фильтра: {{ processingDiagnostics.noiseSuppressionRuntime.initDurationMs.toFixed(1) }} мс.</p>
        <p v-if="processingDiagnostics.noiseSuppressionRuntime.contextSampleRate">AudioContext: {{ processingDiagnostics.noiseSuppressionRuntime.contextSampleRate }} Гц.</p>
        <p v-if="processingDiagnostics.noiseSuppressionRuntime.processedFrames !== undefined">Кадры: {{ processingDiagnostics.noiseSuppressionRuntime.processedFrames }}; ошибки: {{ processingDiagnostics.noiseSuppressionRuntime.processorErrors ?? 0 }}.</p>
      </details>
    </fieldset>
    <template v-if="state === 'READY'">
      <label>
        Микрофон
        <select :value="selectedInput" @change="choose('audioinput', $event)">
          <option v-for="device in devices.inputs" :key="device.id" :value="device.id">{{ device.label }}</option>
        </select>
      </label>
      <label>
        Динамик
        <select :value="selectedOutput" @change="choose('audiooutput', $event)">
          <option v-for="device in devices.outputs" :key="device.id" :value="device.id">{{ device.label }}</option>
        </select>
      </label>
      <p v-if="!connected" class="state">До подключения выбор устройства используется для локальной проверки; устройство звонка можно переключить после входа.</p>
      <AudioDeviceCheck :input-id="selectedInput" :output-id="selectedOutput" :processing="processing" :connected="connected" :microphone-track="microphoneTrack" />
    </template>
  </section>
</template>
