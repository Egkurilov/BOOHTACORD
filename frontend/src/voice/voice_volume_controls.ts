import { ref } from 'vue'

import { loadCurrentSession } from '../identity/current_session'
import { normalizeAudioVolume } from './audio_gain'
import type { RemoteParticipantCard } from './remote_participant_controller'
import type { ScreenViewerController } from './screen_viewer_controller'
import { createVoiceSelfSpeaking, type VoiceActivitySource } from './voice_self_speaking'
import { VoiceVolumePreferences } from './voice_volume_preferences'

interface RemoteVoiceVolumeSource extends VoiceActivitySource {
  setVolume(id: string, percent: number): void
}

interface RemoteParticipantVolumeSource {
  cards(): RemoteParticipantCard[]
  onChange(listener: () => void): () => void
}

export interface VoiceVolumeSession {
  participantCards(): RemoteParticipantVolumeSource | null
  remoteVoices(): RemoteVoiceVolumeSource | null
  screenViewer(): ScreenViewerController | null
}

export type VoiceVolumeParticipant = RemoteParticipantCard & { volume: number }
type AccountLoader = () => Promise<{ accountId: string }>

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
  const participants = ref<VoiceVolumeParticipant[]>([])
  const selectedScreenVolume = ref(100)
  const selfVoice = createVoiceSelfSpeaking(session)
  let stopRemote: () => void = () => undefined
  let stopScreen: () => void = () => undefined
  let revision = 0

  function syncRemote(): void {
    const cards = session.participantCards()
    participants.value = (cards?.cards() ?? []).map((card) => {
      const volume = card.accountId ? preferences.participant(card.accountId) : 100
      session.remoteVoices()?.setVolume(card.id, volume)
      return { ...card, volume }
    })
  }

  function syncScreen(): void {
    const viewer = session.screenViewer()
    const accountId = viewer?.selectedAccountId
    selectedScreenVolume.value = accountId ? preferences.screen(accountId) : 100
    viewer?.setAudioVolume(selectedScreenVolume.value)
  }

  async function start(): Promise<void> {
    stopRemote()
    stopScreen()
    selfVoice.stop()
    const current = ++revision
    error.value = null
    let ownAccountId: string | null = null
    try {
      ownAccountId = (await loadAccount()).accountId
      preferences.bind(ownAccountId)
    } catch {
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
    error.value = null
  }

  function setParticipantVolume(id: string, percent: number): void {
    const participant = participants.value.find((candidate) => candidate.id === id)
    if (!participant?.accountId) return
    const volume = normalizeAudioVolume(percent)
    session.remoteVoices()?.setVolume(id, volume)
    preferences.setParticipant(participant.accountId, volume)
    syncRemote()
  }

  function setScreenVolume(percent: number): void {
    const viewer = session.screenViewer()
    if (!viewer?.selectedAccountId) return
    const volume = normalizeAudioVolume(percent)
    viewer.setAudioVolume(volume)
    preferences.setScreen(viewer.selectedAccountId, volume)
    selectedScreenVolume.value = volume
  }

  return { error, participants, selfSpeaking: selfVoice.selfSpeaking, selectedScreenVolume, setParticipantVolume, setScreenVolume, start, stop, syncScreen }
}
