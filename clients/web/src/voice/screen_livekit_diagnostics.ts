import {
  normalizeScreenDiagnostics,
  type ScreenDiagnostics,
  type ScreenSenderStats,
} from './screen_diagnostics'
import { ScreenPacketLossWindow } from './screen_packet_loss'

const losses = new WeakMap<LiveKitScreenVideoTrack, { stream?: string; window: ScreenPacketLossWindow }>()

export interface LiveKitScreenVideoTrack {
  currentBitrate?: number
  getSenderStats(): Promise<ScreenSenderStats[]>
  getSourceTrackSettings(): MediaTrackSettings
  mediaStreamTrack: { readyState: string }
}

function preferredSender(stats: ScreenSenderStats[]): ScreenSenderStats | undefined {
  return stats.reduce<ScreenSenderStats | undefined>((preferred, candidate) => {
    const preferredPixels = (preferred?.frameWidth ?? 0) * (preferred?.frameHeight ?? 0)
    const candidatePixels = (candidate.frameWidth ?? 0) * (candidate.frameHeight ?? 0)
    return candidatePixels > preferredPixels ? candidate : preferred
  }, stats[0])
}

export async function inspectLiveKitScreenDiagnostics(
  video: LiveKitScreenVideoTrack | undefined,
  audioTrack: boolean,
  connectionQuality: string,
): Promise<ScreenDiagnostics> {
  let sender: ScreenSenderStats | undefined
  try {
    sender = video ? preferredSender(await video.getSenderStats()) : undefined
  } catch {
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
  return { ...normalizeScreenDiagnostics({
    audioTrack,
    bitrateBps: video?.currentBitrate,
    connectionQuality,
    readyState: video?.mediaStreamTrack.readyState,
    sender,
    settings: video?.getSourceTrackSettings(),
  }), sampledAt: Date.now(), senderStatsAvailable: sender !== undefined,
    senderDimensionsAvailable: Boolean(sender?.frameWidth && sender?.frameHeight),
    packetLossPercent: loss, packetLossWindowMs: windowMs }
}
