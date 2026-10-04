import { ref } from 'vue'
import type { VoiceVolumeSession, VoiceVolumeParticipant } from './types'
import type { VoiceVolumePreferences } from './preferences'
export function createVolumeView(session: VoiceVolumeSession, preferences: VoiceVolumePreferences, onError: () => void) {
  const participants = ref<VoiceVolumeParticipant[]>([])
  const selectedScreenVolume = ref(100)
  function syncRemote(): void {
    const cards = session.participantCards()
    participants.value = (cards?.cards() ?? []).map((card) => {
      const volume = card.accountId ? preferences.participant(card.accountId) : 100
      try { session.remoteVoices()?.setVolume(card.id, volume) } catch { onError() }
      return { ...card, volume }
    })
  }

  function syncScreen(): void {
    const viewer = session.screenViewer()
    const accountId = viewer?.selectedAccountId
    selectedScreenVolume.value = accountId ? preferences.screen(accountId) : 100
    try { viewer?.setAudioVolume(selectedScreenVolume.value) } catch { onError() }
  }

  return { participants, selectedScreenVolume, syncRemote, syncScreen }
}
