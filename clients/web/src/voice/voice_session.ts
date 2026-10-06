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
import { activeAction } from '../telemetry/action_scope/scope'
import { telemetrySession } from '../telemetry/action_scope/session'
import type { AudioInputSelection } from './audio_input_selection'
import { reportAudioInputSwitch } from './audio_input_reporting'
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
  constructor(
    private readonly admission: VoiceAdmission = defaultAdmission,
    private readonly joinRoom: RoomJoiner = connectLiveKitRoomWithProcessing,
  ) {}
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
    if (!this.current) telemetrySession.beginMedia()
    return tracedOperation('voice.join', async (within) => {
      if (this.current) throw new Error('Сначала завершите текущее голосовое подключение.')
      let lease: VoiceLease | null = null
      try {
        const action = activeAction()
        if(action)telemetrySession.bindMediaFlow(action.id)
        action?.step('lease')
        const acquired = await within(() => this.admission.acquire(channelId, transfer))
        lease = acquired
        this.monitor.notifyAdmitted(acquired.id, acquired.channelId)
        action?.step('credential')
        const credential = await within(() => this.admission.credential(acquired.id))
        action?.step('connect')
        const joined = await within(() => this.joinRoom(credential, this.audioProcessing.value, joinMode, this.inputDeviceId))
        this.current = { listenerOnly: joinMode === 'listener', channelId: lease.channelId, leaseId: lease.id, screenProfile: null, ...joined }
        const observeInput = (selection: AudioInputSelection) => {
          if (this.current?.room !== joined.room) return
          this.inputDeviceId = selection.deviceId
          if (selection.outcome === 'error') {
            this.current.microphone = 'MUTED'
            this.deafen.invalidateMicrophoneRestore()
          }
        }
        this.stopInputSelection = joined.room.onAudioInputSelection?.(observeInput)
        const selected = joined.room.readAudioInputSelection?.()
        if (selected) observeInput(selected)
        this.monitor.bind(joined.room, () => this.current?.room === joined.room, () => this.handleDisconnected(joined.room))
        action?.span.setAttribute('app.voice.mode',this.current.microphone==='LISTENER_PERMISSION_DENIED'?'microphone_unavailable':this.current.listenerOnly?'listener':'participant')
        action?.step('ready')
        return this.current
      } catch (cause) {
        telemetrySession.endMedia()
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
        this.stopInputSelection?.()
        this.stopInputSelection = undefined
        this.current = null
        telemetrySession.endMedia()
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
      this.stopInputSelection?.()
      this.stopInputSelection = undefined
      this.current = null
      telemetrySession.endMedia()
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
    if (microphone === 'PUBLISHED') current.listenerOnly = false
    return microphone
  }

  async setDeafened(deafened: boolean): Promise<MicrophoneState> {
    return this.deafen.set(deafened)
  }

  async setAudioProcessing(options: AudioProcessingOptions): Promise<void> { await this.audioProcessing.set(options) }

  async switchAudioDevice(kind: AudioDeviceKind, deviceId: string): Promise<AudioInputSelection | undefined> {
    const current = this.current
    if (!current) {
      if (kind !== 'audioinput') throw new Error('Сначала подключитесь к голосовому каналу.')
      this.inputDeviceId = deviceId
      reportAudioInputSwitch('prejoin', 'success')
      return this.inputSelection
    }
    if (kind === 'audioinput' && this.inputSelection.deviceId === deviceId && this.inputSelection.outcome !== 'error') return this.inputSelection
    try {
      const switched = await current.room.switchActiveDevice(kind, deviceId)
      if (this.current !== current) throw new Error('Голосовое подключение закрыто.')
      if (!switched && (kind !== 'audioinput' || !current.room.readAudioInputSelection)) throw new Error('Браузер не смог переключить выбранное аудиоустройство.')
      if (kind === 'audioinput') {
        this.inputDeviceId = current.room.readAudioInputSelection?.().deviceId ?? deviceId
        return this.inputSelection
      }
    } catch (cause) {
      if (this.current !== current) throw new Error('Голосовое подключение закрыто.')
      const selection = kind === 'audioinput' ? current.room.readAudioInputSelection?.() : undefined
      if (selection?.outcome === 'error') { current.microphone = 'MUTED'; this.deafen.invalidateMicrophoneRestore(); return selection }
      throw cause
    }
  }

  async updateScreenProfile(profile: ScreenProfile) { return this.screen.updateScreenProfile(profile) }

  private async handleDisconnected(room: JoinedVoiceRoom['room']): Promise<void> {
    const current = this.current
    if (!current || current.room !== room) return
    this.stopInputSelection?.()
    this.stopInputSelection = undefined
    this.current = null
    telemetrySession.endMedia()
    this.deafen.reset()
    this.monitor.notifyDisconnected()
    await this.admission.release(current.leaseId).catch(() => undefined)
  }
}
