import { onScopeDispose,ref,shallowRef,watch,type Ref } from 'vue'
import type { ActiveVoiceSession,VoiceSession } from '../voice_session'
import type { AudioProcessingOptions } from '../livekit_gateway'
import type { AudioDeviceKind } from '../audio_devices'
import type { AudioInputSelection } from '../audio_input_selection'
export function createProcessingState(session:VoiceSession,active:Ref<ActiveVoiceSession|null>,microphoneMuted:Ref<boolean>) {
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

  async function switchAudioDevice(kind: AudioDeviceKind, deviceId: string): Promise<void> {
    if (!active.value) throw new Error('Сначала подключитесь к голосовому каналу.')
    await session.switchAudioDevice(kind, deviceId)
    refreshAudioProcessingDiagnostics()
  }

  async function setInputDevice(deviceId: string): Promise<AudioInputSelection> {
    try { return (await session.switchAudioDevice('audioinput', deviceId))! }
    finally { refreshAudioProcessingDiagnostics() }
  }

  return {microphoneTrack,inputSelection,audioProcessingDiagnostics,refreshAudioProcessingDiagnostics,setAudioProcessing,switchAudioDevice,setInputDevice}
}
