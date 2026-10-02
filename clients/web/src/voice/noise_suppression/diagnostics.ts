export interface RnnoiseCounters {
  processedFrames: number
  fifoUnderruns: number
  fifoOverruns: number
  processorErrors: number
}
export function readRnnoiseCounters(message: unknown): RnnoiseCounters | undefined {
  if (!message || typeof message !== 'object') return
  const value = message as Record<string, unknown>
  for (const key of ['processedFrames', 'fifoUnderruns', 'fifoOverruns', 'processorErrors']) {
    if (typeof value[key] !== 'number' || !Number.isSafeInteger(value[key]) || (value[key] as number) < 0) return
  }
  return { processedFrames: value.processedFrames as number, fifoUnderruns: value.fifoUnderruns as number,
    fifoOverruns: value.fifoOverruns as number, processorErrors: value.processorErrors as number }
}
