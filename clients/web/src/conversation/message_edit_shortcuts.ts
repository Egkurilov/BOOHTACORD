type EditKeyEvent = Pick<KeyboardEvent, 'key' | 'keyCode' | 'ctrlKey' | 'metaKey' | 'altKey' | 'isComposing' | 'preventDefault' | 'stopPropagation'>

export function handleMessageEditKeydown(event: EditKeyEvent, cancel: () => void, save: () => void): void {
  if (event.isComposing || event.keyCode === 229) return
  if (event.key === 'Escape') {
    event.preventDefault()
    event.stopPropagation()
    cancel()
    return
  }
  if (event.key === 'Enter' && (event.ctrlKey || event.metaKey) && !event.altKey) {
    event.preventDefault()
    event.stopPropagation()
    save()
  }
}
