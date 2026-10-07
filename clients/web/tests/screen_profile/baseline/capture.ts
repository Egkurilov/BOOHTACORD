import { drawFrameMarker } from './frame_marker'
import { baselinePlan } from './settings'

export function createSyntheticCapture(onFrame: (frame: number) => void, captureFps = baselinePlan.frameRate) {
  if (![15, 30, baselinePlan.frameRate].includes(captureFps)) throw new Error('unsupported synthetic source FPS control')
  const canvas = document.createElement('canvas')
  canvas.width = baselinePlan.width
  canvas.height = baselinePlan.height
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
    context.fillText(`Frame ${frame} | ${Math.round(performance.now())} ms`, 32, 96)
    drawFrameMarker(context, frame)
    animationFrame = requestAnimationFrame(draw)
  }
  animationFrame = requestAnimationFrame(draw)
  return { stream: canvas.captureStream(captureFps), stop: () => cancelAnimationFrame(animationFrame) }
}

export function createDisplayCapture() {
  return navigator.mediaDevices.getDisplayMedia({
    video: { frameRate: { ideal: 60, max: 60 } },
    audio: false,
  })
}
