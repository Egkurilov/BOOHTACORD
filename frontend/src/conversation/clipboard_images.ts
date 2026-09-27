function clipboardFiles(data: DataTransfer | null): File[] {
  if (!data) return []
  const fromItems = Array.from(data.items)
    .filter((item) => item.kind === 'file' && item.type.toLowerCase().startsWith('image/'))
    .map((item) => item.getAsFile())
    .filter((file): file is File => file !== null)
  const candidates = fromItems.length
    ? fromItems
    : Array.from(data.files).filter((file) => file.type.toLowerCase().startsWith('image/'))
  return candidates.map((file, index) => {
    if (file.name.trim() && file.name.toLowerCase() !== 'blob') return file
    const extension = file.type.toLowerCase() === 'image/jpeg'
      ? 'jpg'
      : file.type.split('/')[1]?.replace(/[^a-z0-9]/g, '') || 'png'
    return new File([file], `clipboard-image-${index + 1}.${extension}`, {
      type: file.type,
      lastModified: file.lastModified,
    })
  })
}

export function pasteClipboardImages(
  event: Pick<ClipboardEvent, 'clipboardData' | 'preventDefault'>,
  textarea: Pick<HTMLTextAreaElement, 'selectionStart' | 'selectionEnd' | 'setRangeText' | 'dispatchEvent'>,
  addFiles: (files: File[]) => void,
): boolean {
  const clipboard = event.clipboardData
  const files = clipboardFiles(clipboard)
  if (files.length === 0) return false

  event.preventDefault()
  const text = clipboard?.getData('text/plain') ?? ''
  if (text) {
    textarea.setRangeText(text, textarea.selectionStart, textarea.selectionEnd, 'end')
    textarea.dispatchEvent(new Event('input', { bubbles: true }))
  }
  addFiles(files)
  return true
}
