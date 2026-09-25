export interface SearchShortcutEvent {
  key: string
  ctrlKey: boolean
  metaKey: boolean
  altKey: boolean
  shiftKey: boolean
  repeat: boolean
  isComposing: boolean
  target: unknown
}

export function shouldOpenSearchShortcut(event: SearchShortcutEvent): boolean {
  if (event.key.toLowerCase() !== 'k' || (!event.ctrlKey && !event.metaKey) || event.altKey || event.shiftKey || event.repeat || event.isComposing) return false
  const target = event.target as { closest?: (selectors: string) => unknown } | null
  return !target?.closest?.('input, textarea, select, [contenteditable]:not([contenteditable="false"]), [role="textbox"], [role="searchbox"], [role="dialog"]')
}
