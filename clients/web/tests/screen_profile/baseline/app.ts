import { ScreenBaselineSession } from './session'
import { isSafeLiveKitUrl } from './target'
import { decodedP05Fps, encodedP05Fps, frameSequenceMetrics, presentationMetrics } from './metrics'
import { measurementPlan } from './settings'

const session = new ScreenBaselineSession()
;(window as any).screenBaseline = session

function element<T extends HTMLElement>(selector: string) {
  const found = document.querySelector<T>(selector)
  if (!found) throw new Error(`Missing baseline control: ${selector}`)
  return found
}

element<HTMLButtonElement>('#connect').onclick = () => {
  const status = element<HTMLElement>('#status')
  if (!element<HTMLInputElement>('#isolated-target').checked) {
    status.textContent = 'isolated-test-confirmation-required'
    return
  }
  const url = element<HTMLInputElement>('#url').value
  if (!isSafeLiveKitUrl(url)) {
    status.textContent = 'use-wss-or-loopback-test-endpoint'
    return
  }
  const token = element<HTMLInputElement>('#token').value
  session.configure({
    url,
    token,
    role: element<HTMLSelectElement>('#role').value as 'publisher' | 'viewer',
    numberedSynthetic: element<HTMLInputElement>('#numbered-source').checked,
  })
  element<HTMLInputElement>('#token').value = ''
  void session.connect().catch(() => undefined)
}
element<HTMLButtonElement>('#synthetic').onclick = () => void session.startSynthetic(Number(element<HTMLSelectElement>('#synthetic-fps').value)).catch(() => undefined)
element<HTMLButtonElement>('#display').onclick = () => void session.startDisplayCapture().catch(() => undefined)
element<HTMLButtonElement>('#stop').onclick = () => void session.stop()
element<HTMLButtonElement>('#report').onclick = async () => {
  const status = element<HTMLElement>('#status')
  status.textContent = 'warmup-30s'
  await new Promise(resolve => setTimeout(resolve, measurementPlan.warmupMs))
  status.textContent = 'sampling-180s'
  const samples = await session.collectSamples(measurementPlan.sampleMs, measurementPlan.windowMs)
  const start = samples[0], end = samples.at(-1)!
  const timestamps = samples.slice(1).flatMap(sample => sample.presentationTimestamps)
  const report = {
    schemaVersion: 1,
    sourceRevision: element<HTMLInputElement>('#source-sha').value || 'unavailable',
    sfuImageDigest: element<HTMLInputElement>('#sfu-digest').value || 'unavailable',
    sdkVersion: element<HTMLInputElement>('#sdk-version').value || 'unavailable',
    browser: end.userAgent,
    deviceConfiguration: element<HTMLInputElement>('#device-profile').value || 'unavailable',
    repeatIndex: element<HTMLInputElement>('#repeat-index').value || 'unspecified',
    source: end.source,
    baselineProfileId: end.baselineProfileId,
    role: end.role,
    warmupSeconds: measurementPlan.warmupMs / 1000,
    sampleWindowSeconds: measurementPlan.sampleMs / 1000,
    sampleIntervalSeconds: measurementPlan.windowMs / 1000,
    plannedRepeats: measurementPlan.repeats,
    captureSettings: end.captureSettings,
    captureSettingsProvenance: 'MediaStreamTrack.getSettings; not capture-throughput evidence',
    syntheticSourceFramesDelta: end.source === 'synthetic-moving-canvas' ? end.generatedFrames - start.generatedFrames : null,
    syntheticGenerationFps: end.source === 'synthetic-moving-canvas' ? (end.generatedFrames - start.generatedFrames) / ((end.monotonicMs - start.monotonicMs) / 1000) : null,
    requestedSyntheticCaptureFps: end.requestedSyntheticFps,
    encodedP05Fps: encodedP05Fps(samples),
    decodedP05Fps: decodedP05Fps(samples),
    firstFrameLatencyMs: end.firstFrameLatencyMs,
    sourceSwitchLatencyMs: null,
    presentation: presentationMetrics(timestamps, start.monotonicMs, end.monotonicMs),
    syntheticFrameSequence: frameSequenceMetrics(samples.slice(1).flatMap(sample => sample.presentedFrameIds)),
    statsProvenance: 'LiveKit Track.getRTCStatsReport; only whitelisted RTP/candidate numeric fields are included',
    samples,
    thresholdClaims: false,
  }
  const link = document.createElement('a')
  link.href = URL.createObjectURL(new Blob([JSON.stringify(report, null, 2)], { type: 'application/json' }))
  link.download = 'screen-share-baseline-numeric.json'
  link.click()
  URL.revokeObjectURL(link.href)
}
