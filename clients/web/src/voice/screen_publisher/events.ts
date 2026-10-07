import type { ScreenPublisherPort } from './types'

export interface ScreenPublicationEvent<T, S> { source: S; videoTrack?: T }
export interface ScreenProfileReconnectGuard { suspend(): void; resume(): void; stop(): void }
export function screenPublisherEventHandlers<T, S>(port: ScreenPublisherPort<T>, screenSource: S, guard: ScreenProfileReconnectGuard) {
  return {
    published: (publication: ScreenPublicationEvent<T, S>) => {
      if (publication.source === screenSource && publication.videoTrack) port.trackPublished?.(publication.videoTrack)
    },
    unpublished: (publication: ScreenPublicationEvent<T, S>) => {
      if (publication.source !== screenSource) return
      if (!port.trackUnpublished?.(publication.videoTrack)) guard.stop()
    },
    reconnecting: () => guard.suspend(),
    reconnected: () => guard.resume(),
    disconnected: () => guard.stop(),
  }
}
