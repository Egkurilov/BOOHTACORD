import { normalizeScreenDiagnostics, type ScreenDiagnostics, type ScreenSenderStats } from './screen_diagnostics'
import { ScreenPacketLossWindow } from './screen_packet_loss'
import { ScreenSenderLayerSampler, screenSenderLayerId } from './screen_sender_layers'
import { readLiveKitScreenSenderStats, type LiveKitScreenVideoTrack } from './screen_livekit_sender_stats'
import { screenSenderStatsSampler } from './screen_stats_sampler'
export type { LiveKitScreenVideoTrack } from './screen_livekit_sender_stats'

const losses = new WeakMap<LiveKitScreenVideoTrack, { stream?: string; window: ScreenPacketLossWindow }>()
const observations = new WeakMap<LiveKitScreenVideoTrack, { timestamp: number; diagnostics: ScreenDiagnostics }>()
const generations = new WeakMap<LiveKitScreenVideoTrack, number>()
const samplers = new WeakMap<LiveKitScreenVideoTrack, ScreenSenderLayerSampler>()

export function clearLiveKitScreenDiagnostics(video: LiveKitScreenVideoTrack): void {
  generations.set(video, (generations.get(video) ?? 0) + 1)
  observations.delete(video)
  samplers.get(video)?.clear()
  samplers.delete(video)
  losses.delete(video)
  if (video.sender) screenSenderStatsSampler.clear(video.sender)
}

export async function inspectLiveKitScreenDiagnostics(
  video: LiveKitScreenVideoTrack | undefined,
  audioTrack: boolean,
  connectionQuality: string,
): Promise<ScreenDiagnostics> {
  let layers: ScreenDiagnostics['layers']
  let selectedLayer: ScreenDiagnostics['selectedLayer']
  let totalBitrateBps: number | undefined
  let newestTimestamp: number | undefined
  const generation = video ? generations.get(video) ?? 0 : 0
  let sender: ScreenSenderStats | undefined
  let counters = { capturedFrames: null as number | null, encodedFrames: null as number | null }
  try {
    if (video) {
      let sampler = samplers.get(video)
      if (!sampler) { sampler = new ScreenSenderLayerSampler(); samplers.set(video, sampler) }
      const observed = await readLiveKitScreenSenderStats(video)
      if ((generations.get(video) ?? 0) !== generation) return normalizeScreenDiagnostics({ audioTrack: false })
      const rows = observed.rows
      newestTimestamp = rows.length ? Math.max(...rows.map(row => row.timestamp)) : undefined
      const prior = observations.get(video)
      if (prior && newestTimestamp === prior.timestamp) return prior.diagnostics
      counters = { capturedFrames: null, encodedFrames: null }
      const sample = sampler.sample(rows, Date.now())
      layers = sample.layers
      selectedLayer = sample.selected
      if (layers.length && layers.every(layer => layer.bitrateBps !== null && layer.windowMs === layers![0]?.windowMs) && rows.every(row => row.timestamp === rows[0]?.timestamp)) {
        totalBitrateBps = layers.reduce((sum, layer) => sum + layer.bitrateBps!, 0)
      }
      if (sample.selected) {
        const row = rows.find((candidate, index) => screenSenderLayerId(candidate, index) === sample.selected?.id)
        counters = { capturedFrames: row?.capturedFrames ?? null, encodedFrames: row?.framesEncoded ?? null }
        sender = {
          timestamp: row?.timestamp, streamId: sample.selected.id, packetsSent: row?.packetsSent,
          packetsLost: row?.packetsLost, frameWidth: sample.selected.frameWidth, frameHeight: sample.selected.frameHeight,
          framesPerSecond: sample.selected.framesPerSecond ?? undefined,
          qualityLimitationReason: sample.selected.qualityLimitationReason,
          roundTripTime: row?.roundTripTime,
        }
      }
    }
  } catch {
    if (video) samplers.get(video)?.clear()
    layers = undefined
    sender = undefined
  }
  let loss: number | null = null
  let windowMs: number | null = null
  if (video) {
    let entry = losses.get(video)
    if (!entry || entry.stream !== sender?.streamId) {
      entry = { stream: sender?.streamId, window: new ScreenPacketLossWindow() }
      losses.set(video, entry)
    }
    loss = entry.window.add({ timestamp: sender?.timestamp ?? NaN, packetsSent: sender?.packetsSent, packetsLost: sender?.packetsLost })
    windowMs = entry.window.durationMs
  }
  const diagnostics: ScreenDiagnostics = {
    ...counters, ...normalizeScreenDiagnostics({ audioTrack, bitrateBps: selectedLayer?.bitrateBps ?? undefined,
      connectionQuality, readyState: video?.mediaStreamTrack.readyState, sender, settings: video?.getSourceTrackSettings() }),
    ...(layers ? { layers } : {}), selectedLayer, totalBitrateBps,
    collectionState: video?.isMuted ? 'sdk_paused' : layers?.some(layer => layer.state === 'STALE') ? 'stale' : selectedLayer ? 'active' : layers?.some(layer => layer.state === 'UNKNOWN') ? 'unknown' : layers?.length ? 'inactive' : 'unavailable',
    sampledAt: newestTimestamp === undefined ? undefined : newestTimestamp, senderStatsAvailable: sender !== undefined,
    senderDimensionsAvailable: Boolean(sender?.frameWidth && sender?.frameHeight), packetLossPercent: loss, packetLossWindowMs: windowMs,
  }
  if (video && newestTimestamp !== undefined && Number.isFinite(newestTimestamp)) observations.set(video, { timestamp: newestTimestamp, diagnostics })
  return diagnostics
}
