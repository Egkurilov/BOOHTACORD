import type { ScreenViewerTrack } from './screen_viewer_types'

export class ScreenTrackAttachment {
  private element: HTMLMediaElement | null = null
  private track: ScreenViewerTrack | null = null

  update(track: ScreenViewerTrack | null, element: HTMLMediaElement | null): void {
    if (this.track === track && this.element === element) return
    if (this.track && this.element) this.track.detach(this.element)
    this.track = track
    this.element = element
    if (track && element) track.attach(element)
  }

  clear(): void { this.update(null, null) }
}
