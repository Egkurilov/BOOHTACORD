export interface ScreenDiagnosticsPlacementInput {
  summaryTop: number
  summaryBottom: number
  panelHeight: number
  viewportHeight: number
  edgeInset?: number
  gap?: number
}

export interface ScreenDiagnosticsPlacement {
  placement: 'above' | 'below'
  maxHeight: number
}

export function placeScreenDiagnostics({
  summaryTop,
  summaryBottom,
  panelHeight,
  viewportHeight,
  edgeInset = 16,
  gap = 8,
}: ScreenDiagnosticsPlacementInput): ScreenDiagnosticsPlacement {
  const availableAbove = Math.max(0, summaryTop - edgeInset - gap)
  const availableBelow = Math.max(0, viewportHeight - summaryBottom - edgeInset - gap)
  const placement = panelHeight <= availableBelow || availableBelow >= availableAbove
    ? 'below'
    : 'above'

  return {
    placement,
    maxHeight: placement === 'above' ? availableAbove : availableBelow,
  }
}
