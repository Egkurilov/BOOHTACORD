import type { ScreenViewerCard } from './screen_viewer_types'

export type StreamAlertPhase = 'IDLE' | 'JOINING' | 'RECONNECTING' | 'CONNECTED' | 'LISTENER' | 'LEAVING' | 'ERROR'
type ScreenCard = Pick<ScreenViewerCard, 'id' | 'isLocal'>

export class StreamStartAlert {
  private known = new Set<string>()
  private recoveryKnown = new Set<string>()
  private initialized = false
  private recovering = false

  constructor(private readonly onStart: (id: string) => void) {}

  observe(cards: ScreenCard[], phase: StreamAlertPhase): void {
    if (phase === 'RECONNECTING') {
      if (!this.recovering) this.recoveryKnown = new Set(this.known)
      this.recovering = true
      return
    }
    if (phase !== 'CONNECTED' && phase !== 'LISTENER') {
      this.known.clear()
      this.recoveryKnown.clear()
      this.initialized = false
      this.recovering = false
      return
    }
    const current = new Set(cards.filter((card) => !card.isLocal).map((card) => card.id))
    if (!this.initialized) {
      this.known = current
      this.initialized = true
      return
    }
    const firstNew = [...current].find((id) => !this.known.has(id))
    if (firstNew) this.onStart(firstNew)
    if (this.recovering && ![...this.recoveryKnown].every((id) => current.has(id))) {
      current.forEach((id) => this.known.add(id))
      return
    }
    this.known = current
    this.recoveryKnown.clear()
    this.recovering = false
  }
}
