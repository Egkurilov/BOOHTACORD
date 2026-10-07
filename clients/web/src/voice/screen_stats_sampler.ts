interface SampleEntry {
  sampledAt: number
  report?: RTCStatsReport
  pending?: Promise<RTCStatsReport>
  request?: Promise<RTCStatsReport>
  invalidated?: boolean
}

const minimumPollIntervalMs = 1000
const maximumRequestMs = 2000

export class ScreenSenderStatsSampler {
  private entries = new WeakMap<Pick<RTCRtpSender, 'getStats'>, SampleEntry>()

  read(sender: Pick<RTCRtpSender, 'getStats'>, now = performance.now()): Promise<RTCStatsReport> {
    const current = this.entries.get(sender)
    if (current?.request) return current.pending!
    if (current?.report && now - current.sampledAt < minimumPollIntervalMs) return Promise.resolve(current.report)
    const entry: SampleEntry = { sampledAt: now }
    let timer: ReturnType<typeof setTimeout>
    const timeout = new Promise<RTCStatsReport>((_resolve, reject) => {
      timer = globalThis.setTimeout(() => reject(new Error('screen stats timed out')), maximumRequestMs)
    })
    const request = Promise.resolve().then(() => sender.getStats())
    entry.request = request
    // getStats cannot be cancelled. A logical timeout must not create another
    // simultaneous native request; retry only after this request actually settles.
    void request.then(report => { if (!entry.invalidated) entry.report = report }, () => {}).finally(() => { delete entry.request })
    const pending = Promise.race([request, timeout]).finally(() => { globalThis.clearTimeout(timer) })
    entry.pending = pending
    this.entries.set(sender, entry)
    return pending
  }

  clear(sender: Pick<RTCRtpSender, 'getStats'>): void {
    const entry = this.entries.get(sender)
    if (entry?.request) { entry.invalidated = true; delete entry.report; entry.sampledAt = -Infinity }
    else this.entries.delete(sender)
  }
}

export const screenSenderStatsSampler = new ScreenSenderStatsSampler()
