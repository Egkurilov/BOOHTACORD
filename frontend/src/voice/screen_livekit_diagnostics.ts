import {
  normalizeScreenDiagnostics,
  type ScreenDiagnostics,
  type ScreenSenderStats,
} from './screen_diagnostics'

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
  return normalizeScreenDiagnostics({
    audioTrack,
    bitrateBps: video?.currentBitrate,
    connectionQuality,
    readyState: video?.mediaStreamTrack.readyState,
    sender,
    settings: video?.getSourceTrackSettings(),
  })
}
