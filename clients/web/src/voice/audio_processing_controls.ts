import { ref } from 'vue'

import { loadCurrentSession } from '../identity/current_session'
import { defaultAudioProcessing, type AudioProcessingOptions } from './livekit_gateway'
import { AudioProcessingPreferences } from './audio_processing_preferences'
import { bindMicrophoneAccount, microphoneAccountGeneration } from './microphone_processing/runtime'

export type AudioProcessingApplier = (processing: AudioProcessingOptions) => Promise<void>
type AccountLoader = () => Promise<{ accountId: string }>

async function loadAuthenticatedAccount(): Promise<{ accountId: string }> {
  const session = await loadCurrentSession()
  if (!session) throw new Error('Сессия не найдена.')
  return session
}

function errorMessage(cause: unknown, fallback: string): string {
  return cause instanceof Error ? cause.message : fallback
}

export function createAudioProcessingControls(
  loadAccount: AccountLoader = loadAuthenticatedAccount,
  preferences = new AudioProcessingPreferences(),
) {
  const error = ref<string | null>(null)
  let loadRevision = 0
  const processing = ref<AudioProcessingOptions>({ ...defaultAudioProcessing })

  async function start(apply: AudioProcessingApplier): Promise<void> {
    const revision = ++loadRevision
    const accountGeneration = microphoneAccountGeneration()
    preferences.clear()
    processing.value = { ...defaultAudioProcessing }
    error.value = null
    try {
      const account = (await loadAccount()).accountId
      if (revision !== loadRevision || accountGeneration !== microphoneAccountGeneration()) return
      preferences.bind(account)
      bindMicrophoneAccount(account)
      processing.value = preferences.get()
    } catch {
      if (revision !== loadRevision || accountGeneration !== microphoneAccountGeneration()) return
      error.value = 'Не удалось загрузить настройки обработки микрофона; используются значения по умолчанию.'
    }
    try {
      await apply(processing.value)
    } catch (cause) {
      error.value = errorMessage(cause, 'Не удалось применить настройки обработки микрофона.')
    }
  }

  async function set(next: AudioProcessingOptions, apply: AudioProcessingApplier): Promise<void> {
    error.value = null
    try {
      await apply(next)
      preferences.set(next)
      processing.value = { ...next }
    } catch (cause) {
      error.value = errorMessage(cause, 'Не удалось обновить обработку микрофона.')
    }
  }

  return { error, processing, set, start }
}
