type ComposerKeyEvent = Pick<KeyboardEvent, 'key' | 'shiftKey' | 'ctrlKey' | 'altKey' | 'metaKey' | 'isComposing' | 'preventDefault'>

export function submitOnComposerEnter(event: ComposerKeyEvent, send: () => void | Promise<void>): void {
  if (event.key !== 'Enter' || event.shiftKey || event.ctrlKey || event.altKey || event.metaKey || event.isComposing) return
  event.preventDefault()
  void send()
}
