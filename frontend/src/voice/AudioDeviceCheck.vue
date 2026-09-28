<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue'
import { playSpeakerCheck, startMicrophoneCheck, type MicrophoneCheck } from './audio_check'

const props = defineProps<{ inputId: string; outputId: string }>()
const level = ref(0)
const inputState = ref('Проверка микрофона выключена.')
const outputState = ref('')
const outputBusy = ref(false)
const inputBusy = ref(false)
let probe: MicrophoneCheck | null = null
let timer: ReturnType<typeof setInterval> | null = null
let generation = 0

function stopInput(): void {
  generation++
  inputBusy.value = false
  if (timer) clearInterval(timer)
  timer = null
  const old = probe
  probe = null
  level.value = 0
  inputState.value = 'Проверка микрофона выключена.'
  if (old) void old.stop()
}

async function toggleInput(): Promise<void> {
  if (inputBusy.value) return
  if (probe || timer) { stopInput(); return }
  const version = ++generation
  inputBusy.value = true
  inputState.value = 'Запрашиваем доступ к микрофону…'
  try {
    const started = await startMicrophoneCheck(props.inputId)
    if (version !== generation) { await started.stop(); return }
    probe = started
    inputState.value = 'Говорите: индикатор показывает локальный уровень, звук не отправляется.'
    timer = setInterval(() => { level.value = started.level() }, 100)
  } catch {
    if (version === generation) inputState.value = 'Не удалось проверить микрофон. Проверьте разрешение и выбранное устройство.'
  } finally {
    if (version === generation) inputBusy.value = false
  }
}

async function checkOutput(): Promise<void> {
  if (outputBusy.value) return
  outputBusy.value = true
  outputState.value = 'Воспроизводим короткий сигнал…'
  try { await playSpeakerCheck(props.outputId); outputState.value = 'Сигнал завершён. Если его не было слышно, проверьте системную громкость и динамик.' }
  catch (cause) { outputState.value = cause instanceof Error ? cause.message : 'Не удалось воспроизвести сигнал.' }
  finally { outputBusy.value = false }
}

watch(() => props.inputId, stopInput)
onBeforeUnmount(stopInput)
</script>

<template>
  <fieldset class="audio-device-check">
    <legend>Проверка звука на этом устройстве</legend>
    <div class="audio-device-check__actions">
      <button type="button" :disabled="inputBusy" @click="toggleInput">{{ probe ? 'Остановить проверку микрофона' : 'Проверить микрофон' }}</button>
      <button type="button" :disabled="outputBusy" @click="checkOutput">Проверить динамик</button>
    </div>
    <p role="status">{{ inputState }}</p>
    <meter min="0" max="100" :value="level" aria-label="Уровень микрофона" />
    <p v-if="outputState" role="status">{{ outputState }}</p>
    <p>Проверка локальная: она не подтверждает слышимость у другого участника.</p>
  </fieldset>
</template>
