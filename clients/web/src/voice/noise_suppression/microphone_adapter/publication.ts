import { microphoneConstraints, microphonePublishOptions } from '../../media_publishing'
import { type AudioProcessingOptions } from '../types'
import { inputConstraints, missingAudioInput } from '../../audio_input_selection'

import { MicrophoneAdapterState } from './state'
export abstract class MicrophoneAdapterPublication extends MicrophoneAdapterState {
  protected async create(options: AudioProcessingOptions, generation: number): Promise<void> {
    try {
      let fallback = false
      try { this.track = await this.dependencies.createTrack({ ...microphoneConstraints(options), ...inputConstraints(this.deviceId) }) }
      catch (cause) {
        this.assertCurrent(generation)
        if (this.deviceId === 'default' || !missingAudioInput(cause)) throw cause
        this.track = await this.dependencies.createTrack(microphoneConstraints(options))
        this.deviceId = 'default'
        fallback = true
      }
      this.source = this.track.mediaStreamTrack
      this.silence()
      this.assertCurrent(generation)
      await this.track.mute()
      await this.configure(options, generation)
      this.assertCurrent(generation)
      // All publication starts muted. Only restoreIntent can begin transmission.
      this.silence()
      try {
        await this.dependencies.publishTrack(this.track, microphonePublishOptions)
      } catch (cause) {
        this.assertCurrent(generation)
        // LiveKit cancels in-flight addTrack requests when it restarts signaling.
        // Its next publishTrack waits for reconnection; retain the muted capture
        // and allow one retry instead of closing the room during that recovery.
        if (!(cause instanceof Error) || cause.message !== 'Cancelled publication by calling unpublish' || !this.dependencies.isReconnecting?.()) throw cause
        this.silence()
        await this.dependencies.publishTrack(this.track, microphonePublishOptions)
      }
      this.published = true
      this.assertCurrent(generation)
      this.options = options
      this.watchSource()
      this.confirmInput(fallback ? 'fallback' : 'success', 'prejoin', fallback ? 'Сохранённый микрофон недоступен. Используется системный микрофон.' : undefined)
    } catch (cause) {
      await this.cleanup()
      this.state = { requestedMode: options.noiseSuppressionMode, effectiveMode: 'unknown', status: 'error' }
      if (!this.closed) this.confirmInput('error', 'prejoin', 'Не удалось включить микрофон. Отправка звука выключена.')
      throw cause
    }
  }
  dispose(): Promise<void> {
    if (this.closed) return this.queue.then(() => undefined)
    // Revoke before waiting for a pending create/init/recovery to settle.
    this.closed = true
    this.listeners.clear()
    this.inputListeners.clear()
    this.generation++
    this.desiredEnabled = false
    this.silence()
    const cleanup = this.queue.catch(() => undefined).then(() => this.cleanup())
    this.queue = cleanup
    return cleanup
  }
  protected async cleanup(): Promise<void> {
    this.stopEnded?.()
    this.stopEnded = undefined
    const track = this.track
    this.silence()
    try { await this.removeProcessor() } finally {
      if (track) {
        try { if (this.published) await this.dependencies.unpublishTrack(track) }
        finally { track.stop() }
      }
      this.track = undefined; this.source = undefined; this.published = false
    }
  }
}
