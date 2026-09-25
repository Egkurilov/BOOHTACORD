export function searchReturnFocusTarget(
  previous: HTMLElement | null,
  trigger: HTMLElement | null,
  body: HTMLElement,
  html: HTMLElement,
): HTMLElement | null {
  if (previous?.isConnected && previous !== body && previous !== html) return previous
  return trigger?.isConnected ? trigger : null
}
