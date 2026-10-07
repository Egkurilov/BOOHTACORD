import type { ScreenPublisherPort } from './types'

export interface ScreenPublicationEvent<T, S> { source: S; videoTrack?: T }
export function screenPublisherEventHandlers<T, S>(port: ScreenPublisherPort<T>, screenSource: S, stopGuard: () => void) {
  return {
    published: (publication: ScreenPublicationEvent<T, S>) => {
      if (publication.source === screenSource) port.trackPublished?.()
    },
    unpublished: (publication: ScreenPublicationEvent<T, S>) => {
      if (publication.source !== screenSource) return
      if (!port.trackUnpublished?.(publication.videoTrack)) stopGuard()
    },
  }
}
