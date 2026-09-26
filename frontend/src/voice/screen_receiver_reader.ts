import type { ScreenViewerCard, ScreenViewerTrack } from './screen_viewer_types'

type Reader = NonNullable<ScreenViewerCard['readReceiverStats']>

export function createScreenReceiverReader(): (track: ScreenViewerTrack) => Reader {
  const readers = new WeakMap<ScreenViewerTrack, Reader>()
  return (track) => {
    let reader = readers.get(track)
    if (!reader) {
      reader = () => track.getReceiverStats!()
      readers.set(track, reader)
    }
    return reader
  }
}
