export function createSyntheticCapture(onFrame: (frame: number) => void) {
  const canvas = document.createElement('canvas')
  canvas.width = 1920
  canvas.height = 1080
  const context = canvas.getContext('2d')
  if (!context) throw new Error('canvas unavailable')
  let frame = 0
  let animationFrame = 0
  const draw = () => {
    onFrame(++frame)
    context.fillStyle = frame % 2 ? '#1267a3' : '#b49523'
    context.fillRect(0, 0, canvas.width, canvas.height)
    context.fillStyle = '#ffffff'
    context.font = '48px sans-serif'
    context.fillText(String(frame), 32, 72)
    animationFrame = requestAnimationFrame(draw)
  }
  animationFrame = requestAnimationFrame(draw)
  return { stream: canvas.captureStream(60), stop: () => cancelAnimationFrame(animationFrame) }
}

export function createDisplayCapture() {
  return navigator.mediaDevices.getDisplayMedia({
    video: { frameRate: { ideal: 60, max: 60 } },
    audio: false,
  })
}
