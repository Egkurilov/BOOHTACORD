export interface ScreenViewerTrack {
  attach(element: HTMLMediaElement): HTMLMediaElement
  detach(element: HTMLMediaElement): HTMLMediaElement[]
  getReceiverStats?(): Promise<import('./screen_receiver_diagnostics').ScreenReceiverSnapshot | undefined>
}

export interface ScreenViewerPublication {
  isMuted?: boolean
  name?: string
  setSubscribed?(subscribed: boolean): void
  track?: ScreenViewerTrack
}

export interface ScreenViewerStream {
  accountId?: string
  audio?: ScreenViewerPublication
  hasAudio: boolean
  id: string
  isLocal?: boolean
  participantId: string
  participantName: string
  targetProfile?: string
  video: ScreenViewerPublication
}

export type ScreenViewerCard = Pick<ScreenViewerStream, 'accountId' | 'hasAudio' | 'id' | 'isLocal' | 'participantId' | 'participantName' | 'targetProfile'> & {
  thumbnailUrl?: string
  readReceiverStats?: () => Promise<import('./screen_receiver_diagnostics').ScreenReceiverSnapshot | undefined>
}
