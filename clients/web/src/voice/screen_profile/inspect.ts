import { profileDimensions, profileScale, screenProfile, type ScreenProfile } from './policy'
import type { ProfileSnapshot, ProfileTrack } from './types'
import { screenSenderStatsSampler } from '../screen_stats_sampler'

export async function inspectScreenProfile(track: ProfileTrack, profile: ScreenProfile, previousFrames: Map<string, number>): Promise<ProfileSnapshot> {
  const settings = track.mediaStreamTrack.getSettings(), target = screenProfile(profile)
  const result: ProfileSnapshot = { status: 'checking', reason: 'unavailable', attempts: 0,
    captureWidth: settings.width, captureHeight: settings.height, captureFps: settings.frameRate }
  const encodings = track.sender?.getParameters().encodings
  if (!encodings?.length) return result
  const active = encodings.filter(e => e.active !== false)
  if (!active.length) return { ...result, status: 'inactive', reason: 'none' }
  const dimensions = profileDimensions(profile, settings)
  if ((settings.width ?? 0) > dimensions.width + 2 || (settings.height ?? 0) > dimensions.height + 2 || (settings.frameRate ?? 0) > target.frameRate + 1) {
    return { ...result, status: 'drift', reason: 'capture' }
  }
  const scale = profileScale(profile, settings)
  if (!active.length || active.some(e => e.maxFramerate === undefined || e.maxFramerate > target.frameRate || e.maxBitrate === undefined || e.maxBitrate > target.bitrate || (e.scaleResolutionDownBy ?? 1) + .001 < scale)) {
    return { ...result, status: 'drift', reason: 'configuration' }
  }
  const report = track.sender ? await screenSenderStatsSampler.read(track.sender) : undefined
  let progressing = false, adapted = false, oversized = false
  const seen = new Set<string>()
  report?.forEach((row) => {
    if (row.type !== 'outbound-rtp' || (row.kind ?? row.mediaType) !== 'video' || row.active === false) return
    const encoding = encodings.find(e => e.rid === row.rid) ?? (encodings.length === 1 ? encodings[0] : undefined)
    if (encoding?.active === false) return
    seen.add(row.id)
    const count = row.framesEncoded ?? row.framesSent, previous = previousFrames.get(row.id)
    const advances = Number.isFinite(count) && previous !== undefined ? count > previous : row.framesPerSecond > 0
    if (Number.isFinite(count)) previousFrames.set(row.id, count)
    if (!advances) return
    progressing = true
    const frame = profileDimensions(profile, { width: row.frameWidth, height: row.frameHeight })
    oversized ||= row.frameWidth > frame.width + 2 || row.frameHeight > frame.height + 2
    adapted ||= row.qualityLimitationReason === 'cpu' || row.qualityLimitationReason === 'bandwidth' || row.frameWidth < frame.width - 2 || row.frameHeight < frame.height - 2 || row.framesPerSecond < target.frameRate * .8
  })
  for (const id of previousFrames.keys()) if (!seen.has(id)) previousFrames.delete(id)
  return { ...result, status: oversized ? 'drift' : !progressing ? 'checking' : adapted ? 'adapted' : 'matched',
    reason: oversized ? 'resolution' : !progressing ? 'unavailable' : 'none' }
}
