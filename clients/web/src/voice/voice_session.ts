import {
  acquireVoiceLease,
  issueLiveKitCredential,
  releaseVoiceLease,
} from './admission_client'
import {
  connectLiveKitRoomWithProcessing,
  type MicrophoneState, type AudioProcessingOptions, type ScreenProfile,
  type VoiceJoinMode,
} from './livekit_gateway'
import type { AudioDeviceKind } from './audio_devices'
import type { ScreenViewerController } from './screen_viewer_controller'
import { VoiceReconnectMonitor } from './voice_reconnect_monitor'
import { VoiceDeafen } from './voice_deafen'
import { VoiceAudioProcessing } from './voice_audio_processing'
import { VoiceScreenSession } from './voice_screen_session'
import type { ActiveVoiceSession, RoomJoiner, VoiceAdmission, VoiceConnectionObserver } from './voice_session_types'
import type { AudioInputSelection } from './audio_input_selection'
import { VoiceSessionControls } from './voice_session_controls'
import { VoiceSessionAdmission } from './voice_session_admission'
import { VoiceSessionShutdown } from './voice_session_shutdown'
export type { ActiveVoiceSession, RoomJoiner, VoiceAdmission, VoiceConnectionObserver } from './voice_session_types'
const defaultAdmission: VoiceAdmission = {
  acquire: acquireVoiceLease,
  credential: issueLiveKitCredential,
  release: releaseVoiceLease,
}
export class VoiceSession {
  private current: ActiveVoiceSession | null = null
  private inputDeviceId = 'default'
  private stopInputSelection?: () => void
  private readonly monitor = new VoiceReconnectMonitor()
  readonly audioProcessing = new VoiceAudioProcessing(() => this.current)
  readonly deafen = new VoiceDeafen(() => this.current, () => this.audioProcessing.value)
  readonly screen = new VoiceScreenSession(() => this.current)
  private readonly controls = new VoiceSessionControls({
    current: () => this.current,
    setInputDeviceId: (deviceId) => { this.inputDeviceId = deviceId },
    inputSelection: () => this.inputSelection,
    audioProcessing: this.audioProcessing,
    deafen: this.deafen,
  })
  private readonly admissionFlow: VoiceSessionAdmission
  private readonly shutdown: VoiceSessionShutdown
  constructor(
    private readonly admission: VoiceAdmission = defaultAdmission,
    private readonly joinRoom: RoomJoiner = connectLiveKitRoomWithProcessing,
  ) {
    this.admissionFlow = new VoiceSessionAdmission({
      current: () => this.current,
      setCurrent: (value) => { this.current = value },
      admission: this.admission,
      joinRoom: this.joinRoom,
      inputDeviceId: () => this.inputDeviceId,
      setInputDeviceId: (value) => { this.inputDeviceId = value },
      stopInputSelection: () => this.stopInputSelection,
      setStopInputSelection: (value) => { this.stopInputSelection = value },
      monitor: this.monitor,
      audioProcessing: this.audioProcessing,
      deafen: this.deafen,
      screen: this.screen,
    })
    this.shutdown = new VoiceSessionShutdown({
      current: () => this.current,
      setCurrent: (value) => { this.current = value },
      admission: this.admission,
      monitor: this.monitor,
      screen: this.screen,
      deafen: this.deafen,
      stopInputSelection: () => this.stopInputSelection,
      setStopInputSelection: (value) => { this.stopInputSelection = value },
    })
  }
  get active(): ActiveVoiceSession | null {
    return this.current
  }
  get inputSelection(): AudioInputSelection { return this.current?.room.readAudioInputSelection?.() ?? { deviceId: this.inputDeviceId, outcome: 'success' } }
  setConnectionObserver(observer: VoiceConnectionObserver): void {
    this.monitor.setObserver(observer)
  }
  screenViewer(): ScreenViewerController | null { return this.current?.room.screenViewer ?? null }
  remoteVoices() { return this.current?.room.remoteVoices ?? null }
  participantCards() { return this.current?.room.participantCards ?? null }
  async join(channelId: string, transfer = false, joinMode: VoiceJoinMode = 'with-microphone'): Promise<ActiveVoiceSession> {
    return this.admissionFlow.join(channelId, transfer, joinMode)
  }
  leave(): Promise<void> { return this.shutdown.leave() }
  revoke(leaseId: string): Promise<boolean> { return this.shutdown.revoke(leaseId) }
  async setMicrophoneMuted(muted: boolean): Promise<MicrophoneState> {
    return this.controls.setMicrophoneMuted(muted)
  }

  async setDeafened(deafened: boolean): Promise<MicrophoneState> {
    return this.controls.setDeafened(deafened)
  }

  setAudioProcessing(options: AudioProcessingOptions): Promise<void> { return this.controls.setAudioProcessing(options) }

  async switchAudioDevice(kind: AudioDeviceKind, deviceId: string): Promise<AudioInputSelection | undefined> {
    return this.controls.switchAudioDevice(kind, deviceId)
  }

  async updateScreenProfile(profile: ScreenProfile) { return this.screen.updateScreenProfile(profile) }

}
