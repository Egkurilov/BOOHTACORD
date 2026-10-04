import { ref } from 'vue'

import { loadCurrentSession } from '../../identity/current_session'
import { normalizeAudioVolume } from '../audio_gain'
import { createVoiceSelfSpeaking } from '../voice_self_speaking'
import { VoiceVolumePreferences } from './preferences'

import type { AccountLoader, VoiceVolumeSession } from './types'
import { createVolumeReporter } from './reporting'
import { createVolumeView } from './view'

async function loadAuthenticatedAccount(): Promise<{ accountId: string }> {
  const session = await loadCurrentSession()
  if (!session) throw new Error('Сессия не найдена.')
  return session
}

export function createVoiceVolumeControls(
  session: VoiceVolumeSession,
  loadAccount: AccountLoader = loadAuthenticatedAccount,
  preferences = new VoiceVolumePreferences(),
) {
  const error = ref<string | null>(null)
  const report = createVolumeReporter()
  const stopStatus = preferences.onStatus(() => {
    error.value = preferences.status === 'fallback' ? 'Настройки громкости недоступны; изменения действуют до выхода.' : null
    report(preferences.status)
  })
  const { participants, selectedScreenVolume, syncRemote, syncScreen } = createVolumeView(session, preferences, () => { error.value = 'Не удалось применить громкость. Разговор можно продолжить.'; report('error') })
  const selfVoice = createVoiceSelfSpeaking(session)
  let stopRemote: () => void = () => undefined
  let stopScreen: () => void = () => undefined
  let revision = 0

  async function start(): Promise<void> {
    stopRemote()
    stopScreen()
    selfVoice.stop()
    preferences.unbind(); participants.value = []
    const current = ++revision
    error.value = null
    let ownAccountId: string | null = null
    try {
      ownAccountId = (await loadAccount()).accountId
      if (current !== revision) return
      preferences.bind(ownAccountId)
    } catch {
      if (current !== revision) return
      preferences.unbind()
      error.value = 'Не удалось загрузить настройки громкости; используется 100%.'
    }
    if (current !== revision) return
    stopRemote = session.participantCards()?.onChange(syncRemote) ?? (() => undefined)
    stopScreen = session.screenViewer()?.onChange(syncScreen) ?? (() => undefined)
    if (ownAccountId) selfVoice.start(ownAccountId)
    syncRemote()
    syncScreen()
  }

  function stop(): void {
    revision += 1
    stopRemote()
    stopScreen()
    selfVoice.stop()
    stopRemote = () => undefined
    stopScreen = () => undefined
    participants.value = []
    selectedScreenVolume.value = 100
    preferences.unbind()
    error.value = null
  }

  async function reset(): Promise<void> {
    const current = revision
    try {
      const account = await loadAccount()
      if (current !== revision) return
      preferences.bind(account.accountId)
      preferences.reset(); syncRemote(); syncScreen()
    } catch {
      if (current !== revision) return
      error.value = 'Не удалось сбросить настройки громкости.'
      report('error')
    }
  }
  function dispose(): void { stop(); stopStatus(); preferences.dispose() }

  function setParticipantVolume(id: string, percent: number): void {
    const participant = participants.value.find((candidate) => candidate.id === id)
    if (!participant?.accountId) return
    const volume = normalizeAudioVolume(percent)
    preferences.setParticipant(participant.accountId, volume)
    syncRemote()
  }

  function setScreenVolume(percent: number): void {
    const viewer = session.screenViewer()
    if (!viewer?.selectedAccountId) return
    const volume = normalizeAudioVolume(percent)
    preferences.setScreen(viewer.selectedAccountId, volume)
    syncScreen()
  }

  return { reset, dispose, flush: () => preferences.flush(), error, participants, selfSpeaking: selfVoice.selfSpeaking, selectedScreenVolume, setParticipantVolume, setScreenVolume, start, stop, syncScreen }
}
