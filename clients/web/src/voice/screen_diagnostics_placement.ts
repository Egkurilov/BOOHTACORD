export interface ScreenDiagnosticsPlacementInput {
  summaryLeft: number
  summaryRight: number
  summaryTop: number
  summaryBottom: number
  panelHeight: number
  panelWidth: number
  viewportWidth: number
  viewportHeight: number
  edgeInset?: number
  gap?: number
  alignLeft?: boolean
}

export interface ScreenDiagnosticsPlacement {
  placement: 'above' | 'below'
  maxHeight: number
  top: number
  left: number
}

export function placeScreenDiagnostics({
  summaryLeft,
  summaryRight,
  summaryTop,
  summaryBottom,
  panelHeight,
  panelWidth,
  viewportWidth,
  viewportHeight,
  edgeInset = 16,
  gap = 8,
  alignLeft = false,
}: ScreenDiagnosticsPlacementInput): ScreenDiagnosticsPlacement {
  const availableAbove = Math.max(0, summaryTop - edgeInset - gap)
  const availableBelow = Math.max(0, viewportHeight - summaryBottom - edgeInset - gap)
  const placement = panelHeight <= availableBelow || availableBelow >= availableAbove
    ? 'below'
    : 'above'
  const maxHeight = placement === 'above' ? availableAbove : availableBelow
  const renderedHeight = Math.min(panelHeight, maxHeight)
  const width = Math.min(panelWidth, Math.max(0, viewportWidth - edgeInset * 2))
  const preferredLeft = alignLeft ? summaryLeft : summaryRight - width
  const left = Math.min(
    Math.max(edgeInset, preferredLeft),
    Math.max(edgeInset, viewportWidth - edgeInset - width),
  )

  return {
    placement,
    maxHeight,
    top: placement === 'above'
      ? Math.max(edgeInset, summaryTop - gap - renderedHeight)
      : summaryBottom + gap,
    left,
  }
}
