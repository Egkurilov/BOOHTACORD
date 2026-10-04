import { type NoiseSuppressionFallbackReason } from '../types'

import { MicrophoneAdapterRecovery } from './recovery'
export abstract class MicrophoneAdapterIntent extends MicrophoneAdapterRecovery {
  protected silence(): void {
    this.processor?.mute()
    const source = this.processor?.sourceTrack ?? this.source
    if (source) source.enabled = false
    if (this.track) this.track.mediaStreamTrack.enabled = false
  }
  protected async restoreIntent(generation: number): Promise<void> {
    this.assertCurrent(generation)
    if (!this.track) return
    if (this.desiredEnabled && this.state.status !== 'error') {
      await this.track.unmute()
      this.source = this.processor ? this.processor.sourceTrack ?? this.source : this.track.mediaStreamTrack
      this.watchSource()
      if (this.closed || !this.desiredEnabled) this.silence()
      this.assertCurrent(generation)
      // Intent can change while SDK unmute awaits.
      if (!this.desiredEnabled) { this.silence(); await this.track.mute() }
      else {
        await this.processor?.unmute()
        this.assertCurrent(generation)
        if (this.desiredEnabled) this.track.mediaStreamTrack.enabled = true
        else { this.silence(); await this.track.mute() }
      }
    } else { this.silence(); await this.track.mute() }
  }
  protected failMuted(reason?: NoiseSuppressionFallbackReason): void {
    this.desiredEnabled = false
    this.silence()
    this.state = { requestedMode: this.options.noiseSuppressionMode, effectiveMode: 'unknown', status: 'error', ...(reason ? { fallbackReason: reason } : {}) }
  }
  protected async removeProcessor(): Promise<void> {
    const processor = this.processor
    this.processor = undefined
    if (!processor) return
    processor.mute()
    try { await this.track?.stopProcessor() } finally { await processor.destroy() }
  }
  protected watchSource(): void {
    this.stopEnded?.()
    const source = this.source
    if (!source?.addEventListener) return
    const ended = () => {
      if (this.closed || this.source !== source) return
      this.silence()
      void this.switchDevice('default', 'active', true, 'Микрофон отключён. Используется системный микрофон.').catch(() => undefined)
    }
    source.addEventListener('ended', ended)
    this.stopEnded = () => source.removeEventListener('ended', ended)
  }

}
