import {
  acquireVoiceLease,
  issueLiveKitCredential,
  releaseVoiceLease,
  type LiveKitCredential,
  type VoiceLease,
} from './admission_client'
import {
  connectLiveKitRoomWithProcessing,
  setMicrophone,
  type JoinedVoiceRoom,
  type MicrophoneState,
  type AudioProcessingOptions,
  type ScreenProfile,
} from './livekit_gateway'
import type { AudioDeviceKind } from './audio_devices'
import { VoiceReconnectMonitor } from './voice_reconnect_monitor'
import type { ScreenViewerController } from './screen_viewer_controller'
import { VoiceDeafen } from './voice_deafen'
import { VoiceAudioProcessing } from './voice_audio_processing'
import { VoiceScreenSession } from './voice_screen_session'

export interface VoiceAdmission {
  acquire(channelId: string, transfer: boolean): Promise<VoiceLease>
  credential(leaseId: string): Promise<LiveKitCredential>
  release(leaseId: string): Promise<void>
}

export interface ActiveVoiceSession extends JoinedVoiceRoom {
  channelId: string
  leaseId: string
  screenProfile: ScreenProfile | null
}

export type RoomJoiner = (credential: LiveKitCredential, processing?: AudioProcessingOptions) => Promise<JoinedVoiceRoom>
export interface VoiceConnectionObserver {
  disconnected(): void
  reconnected(): void
  reconnecting(): void
}
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

  async join(channelId: string, transfer = false): Promise<ActiveVoiceSession> {
    if (this.current) throw new Error('Сначала завершите текущее голосовое подключение.')

    let lease: VoiceLease | null = null
    try {
      lease = await this.admission.acquire(channelId, transfer)
      const joined = await this.joinRoom(await this.admission.credential(lease.id), this.audioProcessing.value)
      this.current = { channelId: lease.channelId, leaseId: lease.id, screenProfile: null, ...joined }
      this.monitor.bind(joined.room, () => this.current?.room === joined.room, () => this.handleDisconnected(joined.room))
      return this.current
    } catch (cause) {
      if (lease) await this.admission.release(lease.id).catch(() => undefined)
      throw cause
    }
  }

  async leave(): Promise<void> {
    const current = this.current
    if (!current) return

    await this.monitor.whileLeaving(async () => {
      await current.room.disconnect()
      await this.admission.release(current.leaseId)
      this.current = null
      this.deafen.reset()
    })
  }

  async setMicrophoneMuted(muted: boolean): Promise<MicrophoneState> {
    if (!this.current) throw new Error('Сначала подключитесь к голосовому каналу.')
    if (this.deafen.isDeafened && !muted) return this.current.microphone
    this.current.microphone = await setMicrophone(this.current.room, !muted, this.audioProcessing.value)
    return this.current.microphone
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

  private async handleDisconnected(room: JoinedVoiceRoom['room']): Promise<void> {
    const current = this.current
    if (!current || current.room !== room) return
    this.current = null
    this.deafen.reset()
    await this.admission.release(current.leaseId).catch(() => undefined)
    this.monitor.notifyDisconnected()
  }
}
