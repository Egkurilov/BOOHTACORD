const FRAME_BITS = 12
const SIGNATURE = 0xa6
const FRAME_MASK = (1 << FRAME_BITS) - 1
const COLUMNS = 5
const ROWS = 4
const CELL_SIZE = 24
const MARKER_X = 32
const MARKER_Y = 128

export function encodeFrameMarker(frame: number) {
  const signature = Array.from({ length: 8 }, (_, bit) => Boolean(SIGNATURE & (1 << bit)))
  const value = Math.trunc(frame) & FRAME_MASK
  return [...signature, ...Array.from({ length: FRAME_BITS }, (_, bit) => Boolean(value & (1 << bit)))]
}

export function decodeFrameMarker(luma: number[]) {
  if (luma.length < COLUMNS * ROWS || luma.slice(0, 20).some(value => !Number.isFinite(value))) return null
  const bits = luma.slice(0, 20).map(value => value >= 128)
  const signature = bits.slice(0, 8).reduce((value, bit, index) => bit ? value | (1 << index) : value, 0)
  if (signature !== SIGNATURE) return null
  return bits.slice(8).reduce((value, bit, index) => bit ? value | (1 << index) : value, 0)
}

export function drawFrameMarker(context: CanvasRenderingContext2D, frame: number) {
  context.fillStyle = '#ff00ff'
  context.fillRect(MARKER_X - 4, MARKER_Y - 4, COLUMNS * CELL_SIZE + 8, ROWS * CELL_SIZE + 8)
  encodeFrameMarker(frame).forEach((bit, index) => {
    context.fillStyle = bit ? '#ffffff' : '#000000'
    context.fillRect(MARKER_X + (index % COLUMNS) * CELL_SIZE, MARKER_Y + Math.floor(index / COLUMNS) * CELL_SIZE, CELL_SIZE, CELL_SIZE)
  })
}

export function readFrameMarker(video: HTMLVideoElement, canvas: HTMLCanvasElement) {
  if (video.videoWidth < MARKER_X + COLUMNS * CELL_SIZE || video.videoHeight < MARKER_Y + ROWS * CELL_SIZE) return null
  canvas.width = COLUMNS * CELL_SIZE
  canvas.height = ROWS * CELL_SIZE
  const context = canvas.getContext('2d', { willReadFrequently: true })
  if (!context) return null
  context.drawImage(video, MARKER_X, MARKER_Y, canvas.width, canvas.height, 0, 0, canvas.width, canvas.height)
  const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data
  const luma: number[] = []
  for (let index = 0; index < COLUMNS * ROWS; index++) {
    const pixel = ((Math.floor(index / COLUMNS) * CELL_SIZE + CELL_SIZE / 2) * canvas.width + (index % COLUMNS) * CELL_SIZE + CELL_SIZE / 2) * 4
    luma.push((pixels[pixel] + pixels[pixel + 1] + pixels[pixel + 2]) / 3)
  }
  return decodeFrameMarker(luma)
}
