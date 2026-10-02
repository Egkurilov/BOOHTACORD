import {
  acquireVoiceLease,
  issueLiveKitCredential,
  releaseVoiceLease,
  type VoiceLease,
} from './admission_client'
import {
  connectLiveKitRoomWithProcessing,
  setMicrophone,
  type JoinedVoiceRoom,
  type MicrophoneState,
  type AudioProcessingOptions,
  type ScreenProfile,
  type VoiceJoinMode,
} from './livekit_gateway'
import type { AudioDeviceKind } from './audio_devices'
import type { ScreenViewerController } from './screen_viewer_controller'
import { VoiceReconnectMonitor } from './voice_reconnect_monitor'
import { VoiceDeafen } from './voice_deafen'
import { VoiceAudioProcessing } from './voice_audio_processing'
import { VoiceScreenSession } from './voice_screen_session'
import type { ActiveVoiceSession, RoomJoiner, VoiceAdmission, VoiceConnectionObserver } from './voice_session_types'
import { tracedOperation } from '../telemetry/client_tracing'
export type { ActiveVoiceSession, RoomJoiner, VoiceAdmission, VoiceConnectionObserver } from './voice_session_types'
const defaultAdmission: VoiceAdmission = {
  acquire: acquireVoiceLease,
  credential: issueLiveKitCredential,
  release: releaseVoiceLease,
}
export class VoiceSession {
  private current: ActiveVoiceSession | null = null
  private readonly monitor = new VoiceReconnectMonitor()
  readonly audioProcessing = new VoiceAudioProcessing(() => this.current)
  readonly deafen = new VoiceDeafen(() => this.current, () => this.audioProcessing.value)
  readonly screen = new VoiceScreenSession(() => this.current)
  constructor(
    private readonly admission: VoiceAdmission = defaultAdmission,
    private readonly joinRoom: RoomJoiner = connectLiveKitRoomWithProcessing,
  ) {}
  get active(): ActiveVoiceSession | null {
    return this.current
  }
  setConnectionObserver(observer: VoiceConnectionObserver): void {
    this.monitor.setObserver(observer)
  }
  screenViewer(): ScreenViewerController | null { return this.current?.room.screenViewer ?? null }
  remoteVoices() { return this.current?.room.remoteVoices ?? null }
  participantCards() { return this.current?.room.participantCards ?? null }
  async join(channelId: string, transfer = true, joinMode: VoiceJoinMode = 'with-microphone'): Promise<ActiveVoiceSession> {
    return tracedOperation('voice.join', async (within) => {
      if (this.current) throw new Error('Сначала завершите текущее голосовое подключение.')
      let lease: VoiceLease | null = null
      try {
        const acquired = await this.admission.acquire(channelId, transfer)
        lease = acquired
        const joined = await this.joinRoom(await within(() => this.admission.credential(acquired.id)), this.audioProcessing.value, joinMode)
        this.current = { channelId: lease.channelId, leaseId: lease.id, screenProfile: null, ...joined }
        this.monitor.bind(joined.room, () => this.current?.room === joined.room, () => this.handleDisconnected(joined.room))
        return this.current
      } catch (cause) {
        const acquired = lease
        if (acquired) await within(() => this.admission.release(acquired.id)).catch(() => undefined)
        throw cause
      }
    })
  }
  async leave(): Promise<void> {
    return tracedOperation('voice.leave', async (within) => {
      const current = this.current
      if (!current) return
      await this.monitor.whileLeaving(async () => {
        await current.room.disconnect()
        this.current = null
        this.deafen.reset()
        await within(() => this.admission.release(current.leaseId))
      })
    })
  }
  async revoke(leaseId: string): Promise<boolean> {
    const current = this.current
    if (!current || current.leaseId !== leaseId) return false
    await this.monitor.whileLeaving(async () => {
      await current.room.disconnect()
      this.current = null
      this.deafen.reset()
    })
    return true
  }
  async setMicrophoneMuted(muted: boolean): Promise<MicrophoneState> {
    const current = this.current
    if (!current) throw new Error('Сначала подключитесь к голосовому каналу.')
    if (this.deafen.isDeafened && !muted) return current.microphone
    const microphone = await setMicrophone(current.room, !muted, this.audioProcessing.value)
    if (this.current !== current) throw new Error('Голосовое подключение закрыто.')
    current.microphone = microphone
    return microphone
  }

  async setDeafened(deafened: boolean): Promise<MicrophoneState> {
    return this.deafen.set(deafened)
  }

  async setAudioProcessing(options: AudioProcessingOptions): Promise<void> { await this.audioProcessing.set(options) }

  async switchAudioDevice(kind: AudioDeviceKind, deviceId: string): Promise<void> {
    if (!this.current) throw new Error('Сначала подключитесь к голосовому каналу.')
    if (!await this.current.room.switchActiveDevice(kind, deviceId)) {
      throw new Error('Браузер не смог переключить выбранное аудиоустройство.')
    }
  }

  async updateScreenProfile(profile: ScreenProfile) { return this.screen.updateScreenProfile(profile) }

  private async handleDisconnected(room: JoinedVoiceRoom['room']): Promise<void> {
    const current = this.current
    if (!current || current.room !== room) return
    this.current = null
    this.deafen.reset()
    await this.admission.release(current.leaseId).catch(() => undefined)
    this.monitor.notifyDisconnected()
  }
}
