import { defineStore } from 'pinia'
import { computed, onScopeDispose, ref, shallowRef, watch } from 'vue'

import { useAuthorDirectory } from '../identity/author_directory'
import { VoiceSession, type ActiveVoiceSession } from './voice_session'
import type { AudioDeviceKind } from './audio_devices'
import type { AudioProcessingOptions, ScreenProfile, VoiceJoinMode } from './livekit_gateway'
import { createScreenControls, type ScreenShareState } from './screen_controls'
import { unknownScreenDiagnostics, type ScreenDiagnostics } from './screen_diagnostics'
import { createScreenViewerControls } from './screen_viewer_controls'
import type { ScreenViewerCard } from './screen_viewer_controller'
import { createDeafenControls } from './deafen_controls'
import { createMicrophoneControls } from './microphone_controls'
import { createVoiceVolumeControls } from './voice_volume_controls'
import { installVoiceConnectionLifecycle } from './connection_lifecycle'
import { leaveVoiceConnection } from './voice_connection_leave'
import { createVoiceConnectionRevocation } from './voice_connection_revocation'
import { voiceLeaseRevocationMessage } from './voice_lease_revocation_reason'
import { voiceParticipantName } from './voice_participant_name'
import { observeStreamStarts } from './stream_start_runtime'
import { installScreenSenderReporting } from './screen_sender_reporting'
import type { VoiceConnectionQuality } from './voice_connection_quality'
import { monitorVoiceConnectionStats } from './voice_connection_stats_polling'
import { createConnectionReporter } from './report_media/connection'
import type { AudioInputSelection } from './audio_input_selection'
import { installAudioDiagnostics } from './audio_diagnostics/monitor'

export type VoiceConnectionState = 'IDLE' | 'JOINING' | 'RECONNECTING' | 'CONNECTED' | 'LISTENER' | 'LEAVING' | 'ERROR'
export type { ScreenShareState } from './screen_controls'

const session = new VoiceSession()

export const useVoiceConnectionStore = defineStore('voice-connection', () => {
  const active = shallowRef<ActiveVoiceSession | null>(null)
  const microphoneTrack = shallowRef<MediaStreamTrack | undefined>()
  let stopProcessingState: (() => void) | null = null
  let stopInputSelection: (() => void) | null = null
  const inputSelection = ref<AudioInputSelection | null>(null)
  const audioProcessingDiagnostics = ref(session.audioProcessing.diagnostics)
  watch(active, (current) => {
    stopProcessingState?.()
    stopProcessingState = null
    stopInputSelection?.()
    stopInputSelection = null
    refreshAudioProcessingDiagnostics()
    if (!current) return
    stopProcessingState = current.room.onNoiseSuppressionState?.(() => {
      if (active.value !== current) return
      refreshAudioProcessingDiagnostics()
    }) ?? null
    stopInputSelection = current.room.onAudioInputSelection?.(() => {
      if (active.value === current) refreshAudioProcessingDiagnostics()
    }) ?? null
  }, { flush: 'sync' })
  onScopeDispose(() => stopProcessingState?.())
  onScopeDispose(() => stopInputSelection?.())
  const error = ref<string | null>(null)
  const microphoneMuted = ref(false)
  const microphonePermissionDenied = ref(false)
  const deafened = ref(false)
  const transferRequired = ref(false)
  const screenError = ref<string | null>(null)
  const screenDiagnostics = ref<ScreenDiagnostics>(unknownScreenDiagnostics())
  const screenProfile = ref<ScreenProfile | null>(null)
  const screenState = ref<ScreenShareState>('IDLE')
  const rawScreenViewerCards = ref<ScreenViewerCard[]>([])
  const screenViewerError = ref<string | null>(null)
  const screenViewerEnded = ref(false)
  const selectedScreenStreamId = ref<string | null>(null)
  const state = ref<VoiceConnectionState>('IDLE')
  const voiceAudioDiagnostics = installAudioDiagnostics(active, state)
  const connectionQuality = ref<VoiceConnectionQuality>('UNKNOWN')
  const pingMs = ref<number | null>(null)
  const canJoin = computed(() => state.value === 'IDLE' || state.value === 'ERROR')
  let stopVoiceStatsPolling: (() => void) | null = null
  watch([active, state], ([current, phase]) => {
    const readStats = current?.room.readVoiceConnectionStats
    stopVoiceStatsPolling?.()
    stopVoiceStatsPolling = null
    connectionQuality.value = 'UNKNOWN'
    pingMs.value = null
    if (!current || (phase !== 'CONNECTED' && phase !== 'LISTENER') || !readStats) return
    const reportConnection = createConnectionReporter()
    stopVoiceStatsPolling = monitorVoiceConnectionStats(readStats.bind(current.room), (stats) => {
      if (active.value !== current || (state.value !== 'CONNECTED' && state.value !== 'LISTENER')) return
      connectionQuality.value = stats.quality
      pingMs.value = stats.pingMs
      reportConnection(stats)
    }, () => {
      if (active.value !== current) return
      connectionQuality.value = 'UNKNOWN'
      pingMs.value = null
    })
  }, { immediate: true, flush: 'sync' })
  onScopeDispose(() => stopVoiceStatsPolling?.())
  const { refreshScreenDiagnostics, startScreen, stopScreen } = createScreenControls(session.screen, active, screenError, screenProfile, screenState, screenDiagnostics)
  installScreenSenderReporting(screenState, screenDiagnostics, refreshScreenDiagnostics, undefined, () => screenProfile.value)
  const screenViewer = createScreenViewerControls(session, rawScreenViewerCards, selectedScreenStreamId, screenViewerError, screenViewerEnded)
  const { deafenChanging, toggleDeafen } = createDeafenControls(session, deafened, microphoneMuted, microphonePermissionDenied, error)
  const { setMicrophoneMuted, toggleMicrophone } = createMicrophoneControls(session, active, state, deafened, microphoneMuted, microphonePermissionDenied, error)
  const volume = createVoiceVolumeControls(session)
  onScopeDispose(volume.dispose)
  const authors = useAuthorDirectory()
  const voiceVolumeParticipants = computed(() => volume.participants.value.map((participant) => ({ ...participant, name: voiceParticipantName(authors, participant.accountId, participant.name) })))
  const screenViewerCards = computed(() => rawScreenViewerCards.value.map((stream) => ({
    ...stream, participantName: stream.isLocal ? stream.participantName : voiceParticipantName(authors, stream.accountId, stream.participantName) ?? stream.participantName,
  })))
  watch([rawScreenViewerCards, state], ([cards, phase]) => observeStreamStarts(cards, phase), { immediate: true, flush: 'sync' })
  let visibleAccountIds = new Set<string>()
  watch([volume.participants, rawScreenViewerCards], ([participants, streams]) => {
    const next = new Set([...participants.map((participant) => participant.accountId), ...streams.filter((stream) => !stream.isLocal).map((stream) => stream.accountId)].filter((id): id is string => Boolean(id)))
    next.forEach((id) => { if (!visibleAccountIds.has(id)) void authors.ensure(id, undefined, true) })
    visibleAccountIds = next
  }, { immediate: true })
  const revocation = createVoiceConnectionRevocation({ session, active, state, error, deafened, microphoneMuted, microphonePermissionDenied, screenDiagnostics, screenProfile, screenState, screenViewer, volume, refreshAudioProcessingDiagnostics })

  function refreshAudioProcessingDiagnostics(): void {
    audioProcessingDiagnostics.value = session.audioProcessing.diagnostics
    microphoneTrack.value = active.value?.room.readMicrophoneTrack?.()
    inputSelection.value = active.value ? session.inputSelection : null
    if (active.value && inputSelection.value?.outcome === 'error') {
      active.value.microphone = 'MUTED'
      microphoneMuted.value = true
    }
  }

  async function setAudioProcessing(options: AudioProcessingOptions): Promise<void> {
    await session.setAudioProcessing(options)
    refreshAudioProcessingDiagnostics()
  }

  installVoiceConnectionLifecycle(session, active, state, error, microphoneMuted, microphonePermissionDenied, deafened, screenDiagnostics, screenProfile, screenState, screenViewer, volume, refreshAudioProcessingDiagnostics)

  async function join(channelId: string, transfer = true, joinMode: VoiceJoinMode = 'with-microphone'): Promise<void> {
    if (!canJoin.value) return

    state.value = 'JOINING'
    error.value = null
    transferRequired.value = false
    try {
      active.value = await session.join(channelId, transfer, joinMode)
      const revokedReason = revocation.takeJoinRevocation(active.value.leaseId)
      if (revokedReason) { await revocation.revokeLease(active.value.leaseId, revokedReason); return }
      refreshAudioProcessingDiagnostics()
      screenViewer.start()
      await volume.start()
      deafened.value = false
      microphoneMuted.value = active.value.microphone === 'MUTED'
      microphonePermissionDenied.value = active.value.microphone === 'LISTENER_PERMISSION_DENIED'
      state.value = active.value.microphone === 'PUBLISHED' ? 'CONNECTED' : 'LISTENER'
    } catch (cause) {
      const cancelledReason = revocation.takeJoinRevocation('')
      active.value = null
      deafened.value = false
      microphoneMuted.value = false
      microphonePermissionDenied.value = false
      state.value = 'ERROR'
      transferRequired.value = false
      error.value = cancelledReason ? voiceLeaseRevocationMessage(cancelledReason) : cause instanceof Error ? cause.message : 'Не удалось подключиться к голосовому каналу.'
    }
  }

  async function switchAudioDevice(kind: AudioDeviceKind, deviceId: string): Promise<void> {
    if (!active.value) throw new Error('Сначала подключитесь к голосовому каналу.')
    await session.switchAudioDevice(kind, deviceId)
    refreshAudioProcessingDiagnostics()
  }

  async function setInputDevice(deviceId: string): Promise<AudioInputSelection> {
    try { return (await session.switchAudioDevice('audioinput', deviceId))! }
    finally { refreshAudioProcessingDiagnostics() }
  }

  async function leave(): Promise<void> {
    await leaveVoiceConnection({ session, active, state, error, deafened, screenDiagnostics, screenProfile, screenState, screenViewer, volume, refreshAudioProcessingDiagnostics })
    const reason = revocation.takePostLeaveReason(active.value?.leaseId ?? '')
    if (reason && active.value) await revocation.revokeLease(active.value.leaseId, reason)
  }

  return { resetAudioVolumes: volume.reset, active, voiceAudioDiagnostics, audioProcessingDiagnostics, inputSelection, setInputDevice, microphoneTrack, canJoin, clearScreenStream: screenViewer.clear, connectionQuality, deafenChanging, deafened, disconnectLocal: revocation.disconnectLocal, error, join, leave, microphoneMuted, microphonePermissionDenied, pingMs, refreshScreenDiagnostics, revokeLease: revocation.revokeLease, screenDiagnostics, screenError, screenProfile, screenState, screenViewerCards, screenViewerEnded, screenViewerError, selectScreenStream: screenViewer.select, selectedScreenStreamId, screenAudioMuted: screenViewer.audioMuted, setAudioProcessing, setMicrophoneMuted, startScreen, state, stopScreen, switchAudioDevice, toggleDeafen, toggleMicrophone, toggleScreenAudio: () => screenViewer.toggleAudio(volume.selectedScreenVolume.value, volume.setScreenVolume), transferRequired, voiceVolumeError: volume.error, voiceVolumeParticipants, selfSpeaking: volume.selfSpeaking, selectedScreenAudioVolume: volume.selectedScreenVolume, setParticipantVolume: volume.setParticipantVolume, setScreenVolume: volume.setScreenVolume }
})
