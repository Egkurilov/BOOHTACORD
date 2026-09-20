export class BoundedVoiceReconnectPolicy {
  constructor(private readonly random: () => number = Math.random) {}

  nextRetryDelayInMs(context: { retryCount: number }): number | null {
    if (context.retryCount >= 6) return null
    const base = Math.min(250 * 2 ** context.retryCount, 4000)
    return Math.floor(base * (0.8 + this.random() * 0.4))
  }
}
