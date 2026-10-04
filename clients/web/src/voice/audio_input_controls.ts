import { ref } from 'vue'
import { loadCurrentSession } from '../identity/current_session'
import { AudioInputPreferences } from './audio_input_preferences'
import type { AudioInputApplier, AudioInputSelection } from './audio_input_selection'

async function loadAuthenticatedAccount(): Promise<{ accountId: string }> {
  const session = await loadCurrentSession()
  if (!session) throw new Error('Сессия не найдена.')
  return session
}

export function createAudioInputControls(
  loadAccount = loadAuthenticatedAccount,
  preferences = new AudioInputPreferences(),
) {
  const selectedInput = ref('default')
  const warning = ref<string | null>(null)
  const switching = ref(false)
  let epoch = 0
  let bound = false
  let queue: Promise<unknown> = Promise.resolve()

  function observe(result: AudioInputSelection): void {
    if (!bound) return
    selectedInput.value = result.deviceId
    warning.value = result.warning ?? null
    if (!preferences.set(result.deviceId)) warning.value ??= 'Микрофон выбран, но не удалось сохранить настройку для следующего запуска.'
  }
  function applySelection(deviceId: string, apply: AudioInputApplier, version: number): Promise<void> {
    const operation = queue.catch(() => undefined).then(async () => {
      if (version !== epoch || !bound) return
      switching.value = true
      try {
        const confirmed = await apply(deviceId)
        if (version === epoch) observe(confirmed)
      } catch {
        if (version === epoch) warning.value = 'Не удалось переключить микрофон. Сохранён предыдущий выбор.'
      } finally { if (version === epoch) switching.value = false }
    })
    queue = operation
    return operation
  }
  async function start(apply: AudioInputApplier): Promise<void> {
    const version = ++epoch
    bound = false
    switching.value = false
    warning.value = null
    try {
      const account = await loadAccount()
      await queue.catch(() => undefined)
      if (version !== epoch) return
      preferences.bind(account.accountId)
      bound = true
      selectedInput.value = preferences.get()
      await applySelection(selectedInput.value, apply, version)
    } catch {
      if (version !== epoch) return
      selectedInput.value = 'default'
      warning.value = 'Не удалось загрузить настройки микрофона; используется системный микрофон.'
      await apply('default').catch(() => undefined)
    }
  }
  async function select(deviceId: string, apply: AudioInputApplier): Promise<void> {
    if (!bound) await start(apply)
    await applySelection(deviceId, apply, epoch)
  }
  return { selectedInput, warning, switching, start, select, observe }
}
