export type SmokeSnapshot = {
  publicationDiscovered: boolean
  subscriptionActive: boolean
  activeVideoTracks: number
  presentedFrameCallbacks: number
  firstFrameLatencyMs: number | null
  syntheticFramesProduced: number
  videoWidth: number
  videoHeight: number
  sourceCapture: MediaTrackSettings | null
  outboundFramesEncoded: number
  inboundFramesDecoded: number
  publisherRemoved: boolean
}

export type SmokeApi = {
  open(url: string, token: string, role: 'publisher' | 'viewer'): Promise<void>
  publishSynthetic(): Promise<void>
  select(): void
  unselect(): void
  snapshot(): Promise<SmokeSnapshot>
  stop(): Promise<void>
}

declare global {
  interface Window { screenShareSfuSmoke: SmokeApi }
}

export {}
