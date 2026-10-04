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
  let loadSequence = 0
  let accountId: string | null = null
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
    const sequence = ++loadSequence
    try {
      const account = await loadAccount()
      if (sequence !== loadSequence) return
      if (!bound || accountId !== account.accountId) {
        // Only an account change revokes pending results. A join/settings refresh
        // for the same account must first let its selection finish saving.
        ++epoch
        bound = false
        switching.value = false
        warning.value = null
        await queue.catch(() => undefined)
        if (sequence !== loadSequence) return
        preferences.bind(account.accountId)
        accountId = account.accountId
        bound = true
      } else {
        await queue.catch(() => undefined)
        if (sequence !== loadSequence) return
      }
      selectedInput.value = preferences.get()
      await applySelection(selectedInput.value, apply, epoch)
    } catch {
      if (sequence !== loadSequence) return
      ++epoch
      bound = false
      switching.value = false
      await queue.catch(() => undefined)
      if (sequence !== loadSequence) return
      selectedInput.value = 'default'
      warning.value = 'Не удалось загрузить настройки микрофона; используется системный микрофон.'
      queue = queue.catch(() => undefined).then(() => sequence === loadSequence ? apply('default') : undefined).catch(() => undefined)
      await queue
    }
  }
  async function select(deviceId: string, apply: AudioInputApplier): Promise<void> {
    if (!bound) await start(apply)
    await applySelection(deviceId, apply, epoch)
  }
  return { selectedInput, warning, switching, start, select, observe }
}
