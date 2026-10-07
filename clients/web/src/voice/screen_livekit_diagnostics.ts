import { normalizeScreenDiagnostics, type ScreenDiagnostics, type ScreenSenderStats } from './screen_diagnostics'
import { ScreenPacketLossWindow } from './screen_packet_loss'
import { ScreenSenderLayerSampler } from './screen_sender_layers'
import { readLiveKitScreenSenderStats, type LiveKitScreenVideoTrack } from './screen_livekit_sender_stats'
import { screenSenderStatsSampler } from './screen_stats_sampler'
export type { LiveKitScreenVideoTrack } from './screen_livekit_sender_stats'

const losses = new WeakMap<LiveKitScreenVideoTrack, { stream?: string; window: ScreenPacketLossWindow }>()
const samplers = new WeakMap<LiveKitScreenVideoTrack, ScreenSenderLayerSampler>()

export function clearLiveKitScreenDiagnostics(video: LiveKitScreenVideoTrack): void {
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
  let sender: ScreenSenderStats | undefined
  let counters = { capturedFrames: null as number | null, encodedFrames: null as number | null }
  try {
    if (video) {
      let sampler = samplers.get(video)
      if (!sampler) { sampler = new ScreenSenderLayerSampler(); samplers.set(video, sampler) }
      const observed = await readLiveKitScreenSenderStats(video)
      const rows = observed.rows
      counters = observed.counters
      const sample = sampler.sample(rows, Date.now())
      layers = sample.layers
      if (sample.selected) {
        const row = rows.find((candidate, index) => (candidate.id ?? `${candidate.ssrc ?? ''}:${candidate.rid ?? ''}:${index}`) === sample.selected?.id)
        sender = {
          timestamp: row?.timestamp, streamId: row?.id, packetsSent: row?.packetsSent,
          packetsLost: row?.packetsLost, frameWidth: sample.selected.frameWidth, frameHeight: sample.selected.frameHeight,
          framesPerSecond: sample.selected.framesPerSecond ?? undefined,
          qualityLimitationReason: sample.selected.qualityLimitationReason,
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
  return {
    ...counters, ...normalizeScreenDiagnostics({ audioTrack, bitrateBps: video?.currentBitrate,
      connectionQuality, readyState: video?.mediaStreamTrack.readyState, sender, settings: video?.getSourceTrackSettings() }),
    ...(layers ? { layers } : {}), sampledAt: Date.now(), senderStatsAvailable: sender !== undefined,
    senderDimensionsAvailable: Boolean(sender?.frameWidth && sender?.frameHeight), packetLossPercent: loss, packetLossWindowMs: windowMs,
  }
}
