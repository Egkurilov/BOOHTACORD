import type { Ref } from 'vue'
import type { VoiceDisconnectState } from './state'

import type { ActiveVoiceSession, VoiceSession } from '../voice_session'
import type { VoiceConnectionState } from '../connection_store'
import type { ScreenDiagnostics } from '../screen_diagnostics'
import type { ScreenProfile } from '../livekit_gateway'
import type { ScreenShareState } from '../screen_controls'

export interface RevocationContext {
  session: Pick<VoiceSession, 'revoke'>
  active: Ref<ActiveVoiceSession | null>
  state: Ref<VoiceConnectionState>
  error: Ref<string | null>
  deafened: Ref<boolean>
  microphoneMuted: Ref<boolean>
  microphonePermissionDenied: Ref<boolean>
  screenDiagnostics: Ref<ScreenDiagnostics>
  screenProfile: Ref<ScreenProfile | null>
  screenState: Ref<ScreenShareState>
  screenViewer: { stop(): void }
  volume: { stop(): void }
  terminal?: VoiceDisconnectState
  refreshAudioProcessingDiagnostics(): void
}

