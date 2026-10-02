export interface ScreenFullscreenTarget {
  requestFullscreen?: () => Promise<void>
}

export interface ScreenFullscreenDocument {
  fullscreenElement: ScreenFullscreenTarget | null
  exitFullscreen(): Promise<void>
  addEventListener(type: 'fullscreenchange', listener: () => void): void
  removeEventListener(type: 'fullscreenchange', listener: () => void): void
}

export function createScreenFullscreenControls(
  target: () => ScreenFullscreenTarget | null,
  documentPort: ScreenFullscreenDocument,
  onChange: (active: boolean) => void,
) {
  function sync(): void {
    onChange(Boolean(target() && documentPort.fullscreenElement === target()))
  }

  documentPort.addEventListener('fullscreenchange', sync)
  sync()

  return {
    sync,
    async toggle(): Promise<boolean> {
      const stage = target()
      if (!stage || !stage.requestFullscreen) return false
      if (documentPort.fullscreenElement === stage) await documentPort.exitFullscreen()
      else await stage.requestFullscreen()
      sync()
      return true
    },
    dispose(): void {
      documentPort.removeEventListener('fullscreenchange', sync)
    },
  }
}
