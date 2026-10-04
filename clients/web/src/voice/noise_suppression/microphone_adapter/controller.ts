import { normalizeAudioProcessing, type AudioProcessingOptions } from '../types'

import { MicrophoneAdapterDevice } from './device'
export class LiveKitMicrophoneAdapter extends MicrophoneAdapterDevice {
  setEnabled(enabled: boolean, options: AudioProcessingOptions): Promise<void> {
    if (this.closed) return Promise.reject(new Error('Голосовое подключение закрыто.'))
    this.desiredEnabled = enabled
    if (!enabled) this.silence()
    return this.enqueue(async (generation) => {
      if (!this.track && !this.desiredEnabled) { this.options = normalizeAudioProcessing(options); this.state = { requestedMode: this.options.noiseSuppressionMode, effectiveMode: 'unknown', status: 'idle' }; return }
      if (this.track && this.desiredEnabled && this.state.status === 'error') await this.cleanup()
      if (!this.track) await this.create(normalizeAudioProcessing(options), generation)
      else if (JSON.stringify(this.options) !== JSON.stringify(options)) await this.changeProfile(normalizeAudioProcessing(options), generation)
      await this.restoreIntent(generation)
    })
  }
  setProcessing(options: AudioProcessingOptions): Promise<void> {
    return this.enqueue(async (generation) => {
      const next = normalizeAudioProcessing(options)
      if (!this.track) { this.options = next; this.state = { requestedMode: next.noiseSuppressionMode, effectiveMode: 'unknown', status: 'idle' }; return }
      await this.changeProfile(next, generation)
    })
  }
}
