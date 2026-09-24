import { defineStore } from 'pinia'
import { computed, ref, shallowRef } from 'vue'

import { VoiceSession, type ActiveVoiceSession } from './voice_session'
import type { AudioDeviceKind } from './audio_devices'
import { VoiceRequestError } from './admission_client'
import type { AudioProcessingOptions, ScreenProfile } from './livekit_gateway'
import { createScreenControls, type ScreenShareState } from './screen_controls'
import { unknownScreenDiagnostics, type ScreenDiagnostics } from './screen_diagnostics'
import { createScreenViewerControls } from './screen_viewer_controls'
import type { ScreenViewerCard } from './screen_viewer_controller'
import { createDeafenControls } from './deafen_controls'
import { createMicrophoneControls } from './microphone_controls'
import { createVoiceVolumeControls } from './voice_volume_controls'
import { installVoiceConnectionLifecycle } from './connection_lifecycle'

export type VoiceConnectionState = 'IDLE' | 'JOINING' | 'RECONNECTING' | 'CONNECTED' | 'LISTENER' | 'LEAVING' | 'ERROR'
export type { ScreenShareState } from './screen_controls'

const session = new VoiceSession()

export const useVoiceConnectionStore = defineStore('voice-connection', () => {
  const active = shallowRef<ActiveVoiceSession | null>(null)
  const audioProcessingDiagnostics = ref(session.audioProcessing.diagnostics)
  const error = ref<string | null>(null)
  const microphoneMuted = ref(false)
  const microphonePermissionDenied = ref(false)
  const deafened = ref(false)
  const transferRequired = ref(false)
  const screenError = ref<string | null>(null)
  const screenDiagnostics = ref<ScreenDiagnostics>(unknownScreenDiagnostics())
  const screenProfile = ref<ScreenProfile | null>(null)
  const screenState = ref<ScreenShareState>('IDLE')
  const screenViewerCards = ref<ScreenViewerCard[]>([])
  const screenViewerError = ref<string | null>(null)
  const screenViewerEnded = ref(false)
  const selectedScreenStreamId = ref<string | null>(null)
  const state = ref<VoiceConnectionState>('IDLE')
  const canJoin = computed(() => state.value === 'IDLE' || state.value === 'ERROR')
  const { refreshScreenDiagnostics, startScreen, stopScreen } = createScreenControls(session.screen, active, screenError, screenProfile, screenState, screenDiagnostics)
  const screenViewer = createScreenViewerControls(session, screenViewerCards, selectedScreenStreamId, screenViewerError, screenViewerEnded)
  const { deafenChanging, toggleDeafen } = createDeafenControls(session, deafened, microphoneMuted, microphonePermissionDenied, error)
  const { setMicrophoneMuted, toggleMicrophone } = createMicrophoneControls(session, active, state, deafened, microphoneMuted, microphonePermissionDenied, error)
  const volume = createVoiceVolumeControls(session)

  function refreshAudioProcessingDiagnostics(): void {
    audioProcessingDiagnostics.value = session.audioProcessing.diagnostics
  }

  async function setAudioProcessing(options: AudioProcessingOptions): Promise<void> {
    await session.setAudioProcessing(options)
    refreshAudioProcessingDiagnostics()
  }

  installVoiceConnectionLifecycle(session, active, state, error, microphoneMuted, microphonePermissionDenied, deafened, screenDiagnostics, screenProfile, screenState, screenViewer, volume, refreshAudioProcessingDiagnostics)

  async function join(channelId: string, transfer = false): Promise<void> {
    if (!canJoin.value) return

    state.value = 'JOINING'
    error.value = null
    transferRequired.value = false
    try {
      active.value = await session.join(channelId, transfer)
      refreshAudioProcessingDiagnostics()
      screenViewer.start()
      await volume.start()
      deafened.value = false
      microphoneMuted.value = active.value.microphone === 'MUTED'
      microphonePermissionDenied.value = active.value.microphone === 'LISTENER_PERMISSION_DENIED'
      state.value = active.value.microphone === 'PUBLISHED' ? 'CONNECTED' : 'LISTENER'
    } catch (cause) {
      active.value = null
      deafened.value = false
      microphoneMuted.value = false
      microphonePermissionDenied.value = false
      state.value = 'ERROR'
      transferRequired.value = cause instanceof VoiceRequestError && cause.code === 'ACTIVE_VOICE_LEASE'
      error.value = cause instanceof Error ? cause.message : 'Не удалось подключиться к голосовому каналу.'
    }
  }

  async function switchAudioDevice(kind: AudioDeviceKind, deviceId: string): Promise<void> {
    if (!active.value) throw new Error('Сначала подключитесь к голосовому каналу.')
    await session.switchAudioDevice(kind, deviceId)
  }

  async function leave(): Promise<void> {
    if (!active.value || state.value === 'LEAVING') return

    state.value = 'LEAVING'
    error.value = null
    try {
      screenViewer.stop()
      volume.stop()
      await session.leave()
      active.value = null
      refreshAudioProcessingDiagnostics()
      deafened.value = false
      screenDiagnostics.value = unknownScreenDiagnostics()
      screenProfile.value = null
      screenState.value = 'IDLE'
      state.value = 'IDLE'
    } catch (cause) {
      state.value = 'ERROR'
      error.value = cause instanceof Error ? cause.message : 'Не удалось завершить голосовое подключение.'
    }
  }

  return { active, audioProcessingDiagnostics, canJoin, clearScreenStream: screenViewer.clear, deafenChanging, deafened, error, join, leave, microphoneMuted, microphonePermissionDenied, refreshScreenDiagnostics, screenDiagnostics, screenError, screenProfile, screenState, screenViewerCards, screenViewerEnded, screenViewerError, selectScreenStream: screenViewer.select, selectedScreenStreamId, setAudioProcessing, setMicrophoneMuted, startScreen, state, stopScreen, switchAudioDevice, toggleDeafen, toggleMicrophone, transferRequired, voiceVolumeError: volume.error, voiceVolumeParticipants: volume.participants, selfSpeaking: volume.selfSpeaking, selectedScreenAudioVolume: volume.selectedScreenVolume, setParticipantVolume: volume.setParticipantVolume, setScreenVolume: volume.setScreenVolume }
})
