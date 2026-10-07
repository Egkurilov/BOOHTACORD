export type ScreenCodec = 'vp8' | 'h264'
export interface ScreenCodecCapability { mimeType: string }

export type ScreenCodecDecision =
  | { outcome: 'selected'; codec: ScreenCodec; reason: 'preferred-supported' | 'compatibility-fallback' }
  | { outcome: 'unknown'; codec: 'vp8'; reason: 'capabilities-unavailable' }
  | { outcome: 'unsupported'; reason: 'no-supported-codec' }

export function browserScreenCodecCapabilities(): readonly ScreenCodecCapability[] | null | undefined {
  if (typeof RTCRtpSender === 'undefined' || typeof RTCRtpSender.getCapabilities !== 'function') return undefined
  try { return RTCRtpSender.getCapabilities('video')?.codecs }
  catch { return undefined }
}

export function selectScreenVideoCodec(codecs: readonly ScreenCodecCapability[] | null | undefined): ScreenCodecDecision {
  if (codecs == null) return { outcome: 'unknown', codec: 'vp8', reason: 'capabilities-unavailable' }
  const supported = new Set(codecs.map(({ mimeType }) => mimeType.trim().toLowerCase()))
  if (supported.has('video/vp8')) return { outcome: 'selected', codec: 'vp8', reason: 'preferred-supported' }
  if (supported.has('video/h264')) return { outcome: 'selected', codec: 'h264', reason: 'compatibility-fallback' }
  return { outcome: 'unsupported', reason: 'no-supported-codec' }
}
