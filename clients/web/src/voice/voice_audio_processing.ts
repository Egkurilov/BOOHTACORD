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
    return describeAudioProcessing(this.options, this.current()?.room.readAudioProcessingSettings?.())
  }

  async set(options: AudioProcessingOptions): Promise<void> {
    const next = { ...options }
    const current = this.current()
    if (current) await applyMicrophoneProcessing(current.room, next)
    this.options = next
  }
}
