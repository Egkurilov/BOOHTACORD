export async function navigateWithSettingsGuard(
  hasUnsavedChanges: boolean,
  confirmDiscard: () => Promise<boolean>,
  navigate: () => void | Promise<unknown>,
): Promise<boolean> {
  if (hasUnsavedChanges && !await confirmDiscard()) return false
  await navigate()
  return true
}
