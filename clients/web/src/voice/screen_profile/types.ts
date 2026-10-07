export interface ProfileTrack {
  mediaStreamTrack: Pick<MediaStreamTrack, 'readyState' | 'getSettings' | 'applyConstraints'> & Partial<Pick<MediaStreamTrack, 'contentHint'>>
  sender?: Pick<RTCRtpSender, 'getParameters' | 'setParameters' | 'getStats'>
}
export type ProfileStatus = 'checking' | 'matched' | 'adapted' | 'inactive' | 'drift' | 'repairing' | 'failed'
export type ProfileReason = 'none' | 'capture' | 'configuration' | 'resolution' | 'unavailable'
export interface ProfileSnapshot {
  status: ProfileStatus
  reason: ProfileReason
  attempts: number
  captureWidth?: number
  captureHeight?: number
  captureFps?: number
}
export function abortProfile(): Error { return Object.assign(new Error('Демонстрация изменилась.'), { name: 'AbortError' }) }
export function trackBinding(track: ProfileTrack) {
  return { track, capture: track.mediaStreamTrack, sender: track.sender }
}
export function sameBinding(track: ProfileTrack | undefined, binding: ReturnType<typeof trackBinding>): boolean {
  return track === binding.track && track.mediaStreamTrack === binding.capture && track.sender === binding.sender && binding.capture.readyState === 'live'
}
