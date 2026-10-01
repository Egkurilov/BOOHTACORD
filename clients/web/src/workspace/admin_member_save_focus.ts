interface FocusableAdminAction {
  isConnected: boolean
  focus(): void
}

export function restoreAdminSaveFocus(
  trigger: FocusableAdminAction,
  wasFocused: boolean,
  activeElement: unknown,
  body: unknown,
): boolean {
  if (!wasFocused || !trigger.isConnected || (activeElement !== body && activeElement !== trigger)) return false
  trigger.focus()
  return true
}
