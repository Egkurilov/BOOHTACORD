import type { ScreenViewerTrack } from './screen_viewer_types'

export class ScreenTrackAttachment {
  private element: HTMLMediaElement | null = null
  private track: ScreenViewerTrack | null = null

  update(track: ScreenViewerTrack | null, element: HTMLMediaElement | null): boolean {
    if (this.track === track && this.element === element) return false
    if (this.track && this.element) this.track.detach(this.element)
    this.track = track
    this.element = element
    if (track && element) track.attach(element)
    return true
  }

  clear(): void { this.update(null, null) }
  matchesBinding(track: ScreenViewerTrack | null, element: HTMLMediaElement | null): boolean {
    return this.track === track && this.element === element
  }
  matches(track: ScreenViewerTrack | null, element: HTMLMediaElement | null): boolean {
    return track !== null && element !== null && this.matchesBinding(track, element)
  }
}
