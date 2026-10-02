import { expect, test } from '@playwright/test'

test('real Chromium encoder follows initial and changed profile dimensions', async ({ page }) => {
  await page.goto('/tests/screen_profile/fixture.html')
  await page.waitForFunction(() => typeof (window as any).applyScreenProfile === 'function')
  const result = await page.evaluate(async () => {
    const canvas = document.createElement('canvas')
    canvas.width = 2560; canvas.height = 1440
    const draw = canvas.getContext('2d')!, stream = canvas.captureStream(5)
    const capture = stream.getVideoTracks()[0]!
    const senderPeer = new RTCPeerConnection(), receiverPeer = new RTCPeerConnection()
    const pending: RTCIceCandidate[] = []
    senderPeer.onicecandidate = e => { if (e.candidate) {
      if (receiverPeer.remoteDescription) void receiverPeer.addIceCandidate(e.candidate)
      else pending.push(e.candidate)
    } }
    receiverPeer.onicecandidate = e => { if (e.candidate) void senderPeer.addIceCandidate(e.candidate) }
    let frame = 0
    const timer = setInterval(() => { draw.fillStyle = ++frame % 2 ? '#1267a3' : '#b49523'; draw.fillRect(0, 0, canvas.width, canvas.height) }, 200)
    async function dimensions(sender: RTCRtpSender, width: number, height: number) {
      const until = performance.now() + 10000
      let latest: unknown
      while (performance.now() < until) {
        const stats = [...(await sender.getStats()).values()]
        latest = stats.filter(r => r.type === 'outbound-rtp').map(r => ({ width: r.frameWidth, height: r.frameHeight, frames: r.framesEncoded, fps: r.framesPerSecond, limitation: r.qualityLimitationReason }))
        if (stats.some(r => r.type === 'outbound-rtp' && r.frameWidth === width && r.frameHeight === height && r.framesEncoded > 1)) return [width, height]
        await new Promise(resolve => setTimeout(resolve, 200))
      }
      const { width: captureWidth, height: captureHeight, frameRate } = capture.getSettings()
      throw new Error(`Encoder did not reach ${width}x${height}: ${JSON.stringify({ latest, state: senderPeer.connectionState, captureWidth, captureHeight, frameRate, encodings: sender.getParameters().encodings })}`)
    }
    try {
      const sender = senderPeer.addTrack(capture, stream)
      await senderPeer.setLocalDescription(await senderPeer.createOffer())
      await receiverPeer.setRemoteDescription(senderPeer.localDescription!)
      for (const candidate of pending) await receiverPeer.addIceCandidate(candidate)
      await receiverPeer.setLocalDescription(await receiverPeer.createAnswer())
      await senderPeer.setRemoteDescription(receiverPeer.localDescription!)
      // Isolate size control from congestion adaptation in this synthetic 5fps source.
      // Production keeps maintain-framerate; guard tests cover reduced adaptive output.
      const parameters = sender.getParameters()
      parameters.degradationPreference = 'maintain-resolution'
      await sender.setParameters(parameters)
      const track = { sender, mediaStreamTrack: capture }
      await (window as any).applyScreenProfile(track, 'P1080_60')
      const initial = await dimensions(sender, 1920, 1080)
      await (window as any).applyScreenProfile(track, 'P720_30')
      const changed = await dimensions(sender, 1280, 720)
      await (window as any).applyScreenProfile(track, 'P1440_60')
      const upgraded = await dimensions(sender, 2560, 1440)
      return { initial, changed, upgraded }
    } finally {
      clearInterval(timer); capture.stop(); senderPeer.close(); receiverPeer.close()
    }
  })
  expect(result).toEqual({ initial: [1920, 1080], changed: [1280, 720], upgraded: [2560, 1440] })
})
