type CaptureKeyEvent = Pick<KeyboardEvent, 'key' | 'code' | 'preventDefault' | 'stopPropagation'>

export function capturePttAssignment(event: CaptureKeyEvent, stopRecording: () => void, assign: (code: string) => void): void {
  if (event.key === 'Tab') {
    stopRecording()
    return
  }
  event.preventDefault()
  stopRecording()
  if (event.key === 'Escape') {
    event.stopPropagation()
    return
  }
  assign(event.code)
}
