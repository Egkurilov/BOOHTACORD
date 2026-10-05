import type { NetworkDiagnostics, NetworkTransport } from './model'
export class NetworkAttempt {
  private started: number | null = null
  private stopped: number | null = null
  private previous: Pick<NetworkTransport, 'audioBytesSent' | 'audioBytesReceived'> | null = null
  private value: NetworkDiagnostics = this.empty()
  constructor(private readonly now: () => number = () => performance.now()) {}
  private empty(): NetworkDiagnostics {
    return { outcome: 'idle', signalMs: null, iceObservedMs: null, sdkJoinMs: null, firstRtpObservedMs: null, elapsedMs: null, transports: [] }
  }
  start() { this.started = this.now(); this.stopped = null; this.previous = null; this.value = this.empty(); this.value.outcome = 'connecting' }
  private elapsed() { return this.started === null ? null : Math.max(0, (this.stopped ?? this.now()) - this.started) }
  signal() { this.value.signalMs ??= this.elapsed() }
  ice() { this.value.iceObservedMs ??= this.elapsed() }
  connected() { this.value.sdkJoinMs = this.elapsed(); this.value.outcome = 'connected' }
  failed() { this.value.outcome = 'failed'; this.stopped = this.now() }
  disconnected() {
    if (this.value.outcome !== 'failed') this.value.outcome = 'disconnected'
    this.stopped ??= this.now(); this.previous = null; this.value.transports = []
  }
  observe(value: Pick<NetworkTransport, 'audioBytesSent' | 'audioBytesReceived'>) {
    if (this.previous && ['audioBytesSent', 'audioBytesReceived'].some(key => {
      const field = key as keyof typeof value
      return value[field] !== null && this.previous![field] !== null && value[field]! > this.previous![field]!
    })) this.value.firstRtpObservedMs ??= this.elapsed()
    this.previous = value
  }
  transports(values: NetworkTransport[]) {
    this.value.transports = values
    if (values.some(value => value.selected)) this.ice()
    const sum = (field: 'audioBytesSent' | 'audioBytesReceived') => {
      const present = values.map(value => value[field]).filter((value): value is number => value !== null)
      return present.length ? present.reduce((total, value) => total + value, 0) : null
    }
    this.observe({ audioBytesSent: sum('audioBytesSent'), audioBytesReceived: sum('audioBytesReceived') })
  }
  snapshot(): NetworkDiagnostics { return { ...this.value, elapsedMs: this.elapsed(), transports: this.value.transports.map(value => ({ ...value })) } }
}
