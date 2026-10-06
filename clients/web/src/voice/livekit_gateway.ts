import type { NoiseSuppressionRuntimeState } from './noise_suppression/types'
import type { LiveKitCredential } from './admission_client'
import type { BrowserAudioProcessingSettings } from './audio_processing_diagnostics'
import { BoundedVoiceReconnectPolicy } from './bounded_voice_reconnect_policy'
import {
  adaptiveMediaRoomOptions,
  setMicrophone,
  type AudioProcessingOptions,
  type MicrophonePublishOptions,
  type MicrophoneState,
  type ScreenShareOptions,
  type ScreenProfile,
  type ScreenSharePublishOptions,
} from './media_publishing'
import type { RemoteVoicePlaybackController } from './livekit_screen_viewer_adapter'
import type { RemoteParticipantController } from './remote_participant_controller'
import { ScreenViewerController } from './screen_viewer_controller'
import type { ScreenDiagnostics } from './screen_diagnostics'
import type { VoiceConnectionStats } from './voice_connection_quality'
import { awaitMediaConnection, mediaConnectionTimeoutMs } from './connection_deadline'
import { defaultLiveKitRoomFactory } from './livekit_room_factory'
import type { AudioInputSelection } from './audio_input_selection'
import type { VoiceAudioDiagnostics } from './audio_diagnostics/model'
import type { NetworkDiagnostics } from './network_diagnostics/model'
import { activeAction } from '../telemetry/action_scope/scope'

export {
  readScreenShareDiagnostics,
  applyMicrophoneProcessing,
  defaultAudioProcessing,
  microphoneConstraints,
  setMicrophone,
  startScreenShare,
  stopScreenShare,
  adaptiveMediaRoomOptions,
  type AudioProcessingOptions,
  type MicrophonePublishOptions,
  type MicrophoneState,
  type ScreenProfile,
  type ScreenShareOptions,
  type ScreenSharePublishOptions,
} from './media_publishing'

export interface VoiceRoom {
  connect(url: string, token: string, options?: { autoSubscribe?: boolean }): Promise<void>
  disconnect(): Promise<void>
  on(event: 'reconnecting' | 'reconnected' | 'disconnected', listener: () => void): VoiceRoom
  readScreenDiagnostics?(): Promise<ScreenDiagnostics>
  stopScreenProfileChecks?(): void
  readVoiceConnectionStats?(): Promise<VoiceConnectionStats>
  readVoiceAudioDiagnostics?(): Promise<VoiceAudioDiagnostics>
  readNetworkDiagnostics?(): Promise<NetworkDiagnostics>
  participantCards?: RemoteParticipantController
  remoteVoices?: RemoteVoicePlaybackController
  screenViewer?: ScreenViewerController
  setDeafened?(deafened: boolean): void
  setMicrophone?(enabled: boolean, options: AudioProcessingOptions): Promise<void>
  disposeMicrophone?(): Promise<void>
  readMicrophoneTrack?(): MediaStreamTrack | undefined
  readAudioInputSelection?(): AudioInputSelection
  onAudioInputSelection?(listener: (selection: AudioInputSelection) => void): () => void
  readNoiseSuppressionState?(): NoiseSuppressionRuntimeState
  onNoiseSuppressionState?(listener: (state: NoiseSuppressionRuntimeState) => void): () => void
  applyMicrophoneProcessing?(options: AudioProcessingOptions): Promise<void>
  readAudioProcessingSettings?(): BrowserAudioProcessingSettings | undefined
  switchActiveDevice(kind: 'audioinput' | 'audiooutput', deviceId: string): Promise<boolean>
  localParticipant: {
    setMicrophoneEnabled(enabled: boolean, options: MediaTrackConstraints, publishOptions?: MicrophonePublishOptions): Promise<unknown>
    setScreenShareEnabled(enabled: boolean, options?: ScreenShareOptions, publishOptions?: ScreenSharePublishOptions): Promise<unknown>
    updateScreenShareProfile?(profile: ScreenProfile): Promise<void>
  }
}

export type VoiceRoomFactory = () => VoiceRoom | Promise<VoiceRoom>
export { BoundedVoiceReconnectPolicy }
export { wireLiveKitRoom } from './livekit_room_factory'

export interface JoinedVoiceRoom {
  microphone: MicrophoneState
  room: VoiceRoom
}

export type VoiceJoinMode = 'with-microphone' | 'listener'

export async function connectLiveKitRoom(
  credential: LiveKitCredential,
  makeRoom: VoiceRoomFactory = defaultLiveKitRoomFactory,
  processing?: AudioProcessingOptions,
  timeoutMs = mediaConnectionTimeoutMs,
  joinMode: VoiceJoinMode = 'with-microphone',
  inputDeviceId?: string,
): Promise<JoinedVoiceRoom> {
  const room = await makeRoom()
  try {
    await awaitMediaConnection(room.connect(credential.url, credential.token, { autoSubscribe: false }), timeoutMs)
    if (inputDeviceId !== undefined) await awaitMediaConnection(room.switchActiveDevice('audioinput', inputDeviceId), timeoutMs)
  } catch (cause) {
    await room.disconnect()
    throw cause
  }

  if (joinMode === 'listener') return { room, microphone: 'MUTED' }

  try {
    activeAction()?.step('microphone')
    return { room, microphone: await awaitMediaConnection(setMicrophone(room, true, processing), timeoutMs) }
  } catch (cause) {
    await room.disconnect()
    throw cause
  }
}

export async function connectLiveKitRoomWithProcessing(
  credential: LiveKitCredential,
  processing?: AudioProcessingOptions,
  joinMode: VoiceJoinMode = 'with-microphone',
  inputDeviceId?: string,
): Promise<JoinedVoiceRoom> {
  return connectLiveKitRoom(credential, defaultLiveKitRoomFactory, processing, undefined, joinMode, inputDeviceId)
}
