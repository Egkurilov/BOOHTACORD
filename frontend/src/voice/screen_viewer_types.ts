export interface ScreenViewerTrack {
  attach(element: HTMLMediaElement): HTMLMediaElement
  detach(element: HTMLMediaElement): HTMLMediaElement[]
}

export interface ScreenViewerPublication {
  isMuted?: boolean
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
  video: ScreenViewerPublication
}

export type ScreenViewerCard = Pick<ScreenViewerStream, 'accountId' | 'hasAudio' | 'id' | 'isLocal' | 'participantId' | 'participantName'>
