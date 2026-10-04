import type { VoiceActivitySource } from '../voice_self_speaking'
import type { RemoteParticipantCard } from '../remote_participant_controller'
import type { ScreenViewerController } from '../screen_viewer_controller'
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
export type AccountLoader = () => Promise<{ accountId: string }>

