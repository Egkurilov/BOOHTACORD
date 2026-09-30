import type { VoiceConnectionObserver } from './voice_session'
import { type Span } from '@opentelemetry/api'
import { endTracedOperation, startTracedOperation } from '../telemetry/client_tracing'

export interface ReconnectableVoiceRoom {
  on(event: 'reconnecting' | 'reconnected' | 'disconnected', listener: () => void): unknown
}

export class VoiceReconnectMonitor {
  private leaving = false
  private reconnectSpan: Span | null = null
  private observer: VoiceConnectionObserver | null = null

  setObserver(observer: VoiceConnectionObserver): void {
    this.observer = observer
  }

  notifyDisconnected(): void {
    this.finishReconnect(true)
    this.observer?.disconnected()
  }

  private finishReconnect(failed = false): void {
    if (this.reconnectSpan) endTracedOperation(this.reconnectSpan, 'voice.reconnect', failed)
    this.reconnectSpan = null
  }

  async whileLeaving(action: () => Promise<void>): Promise<void> {
    this.leaving = true
    try { await action() } finally { this.leaving = false }
  }

  bind(room: ReconnectableVoiceRoom, current: () => boolean, disconnected: () => Promise<void>): void {
    room.on('reconnecting', () => { if (current()) { this.reconnectSpan ??= startTracedOperation('voice.reconnect'); this.observer?.reconnecting() } })
    room.on('reconnected', () => { if (current()) { this.finishReconnect(); this.observer?.reconnected() } })
    room.on('disconnected', () => {
      if (current() && !this.leaving) void disconnected()
    })
  }
}
