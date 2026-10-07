type CounterLayer = { rid?: string; framesEncoded?: number | null; framesDecoded?: number | null }
export type BaselineSample = {
  monotonicMs: number
  visibilityState: string
  visibilityRevision?: number
  outbound: { layers: CounterLayer[] }
  inbound?: { layers: CounterLayer[] }
}

export function counterRate(previous: number | null, current: number | null, elapsedMs: number) {
  if (previous === null || current === null || elapsedMs <= 0) return null
  if (!Number.isFinite(previous) || !Number.isFinite(current) || current < previous) return null
  return (current - previous) / (elapsedMs / 1000)
}

function p05CounterFps(samples: BaselineSample[], direction: 'outbound' | 'inbound') {
  const rates: number[] = []
  for (let index = 1; index < samples.length; index++) {
    const start = samples[index - 1], end = samples[index]
    if (start.visibilityState !== 'visible' || end.visibilityState !== 'visible' || start.visibilityRevision !== end.visibilityRevision) continue
    const priorLayers = direction === 'outbound' ? start.outbound.layers : start.inbound?.layers ?? []
    const currentLayers = direction === 'outbound' ? end.outbound.layers : end.inbound?.layers ?? []
    const previous = new Map(priorLayers.map(layer => [layer.rid ?? 'single', direction === 'outbound' ? layer.framesEncoded : layer.framesDecoded]))
    for (const layer of currentLayers) {
      const count = direction === 'outbound' ? layer.framesEncoded : layer.framesDecoded
      const rate = counterRate(previous.get(layer.rid ?? 'single') ?? null, count ?? null, end.monotonicMs - start.monotonicMs)
      if (rate !== null) rates.push(rate)
    }
  }
  rates.sort((left, right) => left - right)
  return rates.length ? rates[Math.max(0, Math.ceil(rates.length * 0.05) - 1)] : null
}

export function encodedP05Fps(samples: BaselineSample[]) { return p05CounterFps(samples, 'outbound') }
export function decodedP05Fps(samples: BaselineSample[]) { return p05CounterFps(samples, 'inbound') }

export function presentationMetrics(timestamps: number[], startMs: number, endMs: number) {
  const times = timestamps.filter(value => Number.isFinite(value) && value >= startMs && value <= endMs)
  const gaps = times.slice(1).map((time, index) => time - times[index]).filter(gap => gap >= 0)
  const longGaps = gaps.filter(gap => gap > 500)
  const duration = endMs - startMs
  const windowRates: number[] = []
  for (let start = startMs; start + 1000 <= endMs; start += 1000) {
    windowRates.push(times.filter(time => time >= start && time < start + 1000).length)
  }
  windowRates.sort((left, right) => left - right)
  return {
    frameCallbacks: times.length,
    presentedFrameCallbackP05Fps: windowRates.length ? windowRates[Math.max(0, Math.ceil(windowRates.length * 0.05) - 1)] : null,
    gapCountOver500Ms: longGaps.length,
    maxGapMs: gaps.length ? Math.max(...gaps) : null,
    excessFreezeRatio: duration > 0 ? longGaps.reduce((sum, gap) => sum + gap - 500, 0) / duration : null,
  }
}

export function frameSequenceMetrics(frameIds: Array<number | null>) {
  let markerFrames = 0, duplicates = 0, skippedFrames = 0
  let previous: number | null = null
  for (const current of frameIds) {
    if (current === null || !Number.isInteger(current)) continue
    markerFrames++
    if (previous !== null) {
      const delta = (current - previous + 4096) % 4096
      if (delta === 0) duplicates++
      else if (delta < 2048) skippedFrames += delta - 1
    }
    previous = current
  }
  return { markerFrames, duplicateFrames: duplicates, skippedFrames }
}
