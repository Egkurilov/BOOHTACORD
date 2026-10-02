import { normalizeAudioProcessing, type NoiseSuppressionRuntimeState } from './noise_suppression/types'
import { applyMicrophoneProcessing, defaultAudioProcessing, type AudioProcessingOptions, type VoiceRoom } from './livekit_gateway'
import { describeAudioProcessing, type AudioProcessingDiagnostics } from './audio_processing_diagnostics'

interface ProcessingVoiceSession {
  room: VoiceRoom
}

export class VoiceAudioProcessing {
  private options: AudioProcessingOptions = { ...defaultAudioProcessing }

  constructor(private readonly current: () => ProcessingVoiceSession | null) {}

  get value(): AudioProcessingOptions {
    return this.options
  }

  get diagnostics(): AudioProcessingDiagnostics {
    return describeAudioProcessing(this.options, this.current()?.room.readAudioProcessingSettings?.(), this.runtimeState)
  }

  get runtimeState(): NoiseSuppressionRuntimeState {
    return this.current()?.room.readNoiseSuppressionState?.() ?? { requestedMode: this.options.noiseSuppressionMode, effectiveMode: 'unknown', status: 'idle' }
  }

  async set(options: AudioProcessingOptions): Promise<void> {
    const next = normalizeAudioProcessing(options)
    const current = this.current()
    if (current) await applyMicrophoneProcessing(current.room, next)
    this.options = next
  }
}
