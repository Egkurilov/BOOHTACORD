export function createComposerDrop(add: (files: File[]) => void, enabled: () => boolean) {
  function onDragOver(event: DragEvent): void {
    if (event.dataTransfer?.types.includes('Files')) event.preventDefault()
  }
  function onDrop(event: DragEvent): void {
    const files = Array.from(event.dataTransfer?.files ?? [])
    if (!files.length) return
    event.preventDefault()
    event.stopPropagation()
    if (enabled()) add(files)
  }
  return { onDragOver, onDrop }
}
