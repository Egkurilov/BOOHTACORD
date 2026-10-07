export interface ScreenPreviewVisibilitySource {
  isVisible(leaseId: string): boolean
  subscribe(listener: () => void): () => void
}

export class ScreenPreviewCardVisibility implements ScreenPreviewVisibilitySource {
  private readonly leases = new Map<Element, string>()
  private readonly visibleCards = new Map<string, Set<Element>>()
  private readonly listeners = new Set<() => void>()

  constructor() {
    if (typeof document !== 'undefined') document.addEventListener('visibilitychange', () => this.notify())
  }

  isVisible(leaseId: string): boolean {
    return typeof document !== 'undefined' && document.visibilityState === 'visible' && Boolean(this.visibleCards.get(leaseId)?.size)
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }

  setCardVisible(element: Element, leaseId: string, visible: boolean): void {
    const oldLease = this.leases.get(element)
    if (!visible || oldLease !== leaseId) this.remove(element)
    if (visible && this.leases.get(element) !== leaseId) {
      this.leases.set(element, leaseId)
      const cards = this.visibleCards.get(leaseId) ?? new Set<Element>()
      cards.add(element)
      this.visibleCards.set(leaseId, cards)
      this.notify()
    }
  }

  forgetCard(element: Element): void { this.remove(element) }

  private remove(element: Element): void {
    const leaseId = this.leases.get(element)
    if (!leaseId) return
    this.leases.delete(element)
    const cards = this.visibleCards.get(leaseId)
    cards?.delete(element)
    if (!cards?.size) this.visibleCards.delete(leaseId)
    this.notify()
  }

  private notify(): void { this.listeners.forEach((listener) => listener()) }
}

export const screenPreviewCardVisibility = new ScreenPreviewCardVisibility()
