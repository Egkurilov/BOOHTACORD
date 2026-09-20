import type { VoiceConnectionObserver } from './voice_session'

export interface ReconnectableVoiceRoom {
  on(event: 'reconnecting' | 'reconnected' | 'disconnected', listener: () => void): unknown
}

export class VoiceReconnectMonitor {
  private leaving = false
  private observer: VoiceConnectionObserver | null = null

  setObserver(observer: VoiceConnectionObserver): void {
    this.observer = observer
  }

  notifyDisconnected(): void {
    this.observer?.disconnected()
  }

  async whileLeaving(action: () => Promise<void>): Promise<void> {
    this.leaving = true
    try { await action() } finally { this.leaving = false }
  }

  bind(room: ReconnectableVoiceRoom, current: () => boolean, disconnected: () => Promise<void>): void {
    room.on('reconnecting', () => { if (current()) this.observer?.reconnecting() })
    room.on('reconnected', () => { if (current()) this.observer?.reconnected() })
    room.on('disconnected', () => {
      if (current() && !this.leaving) void disconnected()
    })
  }
}
