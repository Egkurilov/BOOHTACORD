export function createSyntheticScreen() {
  const canvas = document.createElement('canvas')
  canvas.width = 640
  canvas.height = 360
  const context = canvas.getContext('2d')
  if (!context) throw new Error('synthetic screen canvas unavailable')
  let frame = 0
  const timer = window.setInterval(() => {
    context.fillStyle = ++frame % 2 ? '#2468a4' : '#a47d24'
    context.fillRect(0, 0, canvas.width, canvas.height)
  }, 1000 / 15)
  const stream = canvas.captureStream(15)
  return {
    canvas,
    stream,
    get generatedFrames() { return frame },
    stop: () => {
      window.clearInterval(timer)
      stream.getTracks().forEach(track => track.stop())
      canvas.remove()
    },
  }
}
