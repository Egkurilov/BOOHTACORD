import type { ScreenViewerStream } from './screen_viewer_types'

export function samePublicationGeneration(left: ScreenViewerStream, right: ScreenViewerStream): boolean {
  return left.id === right.id && left.participantId === right.participantId && left.isLocal === right.isLocal && left.video === right.video
}

export function setScreenSubscribed(stream: ScreenViewerStream, subscribed: boolean): void {
  if (stream.isLocal) return
  stream.video.setSubscribed?.(subscribed)
  stream.audio?.setSubscribed?.(subscribed)
}
