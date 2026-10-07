interface SampleEntry {
  sampledAt: number
  report?: RTCStatsReport
  pending?: Promise<RTCStatsReport>
}

const minimumPollIntervalMs = 1000
const maximumRequestMs = 2000

export class ScreenSenderStatsSampler {
  private entries = new WeakMap<Pick<RTCRtpSender, 'getStats'>, SampleEntry>()

  read(sender: Pick<RTCRtpSender, 'getStats'>, now = performance.now()): Promise<RTCStatsReport> {
    const current = this.entries.get(sender)
    if (current?.pending) return current.pending
    if (current?.report && now - current.sampledAt < minimumPollIntervalMs) return Promise.resolve(current.report)
    const entry: SampleEntry = { sampledAt: now }
    let timer: ReturnType<typeof setTimeout>
    const timeout = new Promise<RTCStatsReport>((_resolve, reject) => {
      timer = globalThis.setTimeout(() => reject(new Error('screen stats timed out')), maximumRequestMs)
    })
    const pending = Promise.race([Promise.resolve().then(() => sender.getStats()), timeout]).then(report => {
      entry.report = report
      return report
    }).finally(() => { globalThis.clearTimeout(timer); delete entry.pending })
    entry.pending = pending
    this.entries.set(sender, entry)
    return pending
  }

  clear(sender: Pick<RTCRtpSender, 'getStats'>): void {
    this.entries.delete(sender)
  }
}

export const screenSenderStatsSampler = new ScreenSenderStatsSampler()
