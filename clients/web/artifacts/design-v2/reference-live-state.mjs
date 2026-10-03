// Test transport records drive the real Vue stores; production code is untouched.
export async function installReferenceTransports(page) {
  await page.addInitScript(() => {
    window.WebSocket = class {
      constructor() { this.readyState = 0; setTimeout(() => { this.readyState = 1; this.onopen?.({}) }, 0) }
      send() {}
      close() { this.readyState = 3 }
    }
    window.EventSource = class {
      constructor() {
        setTimeout(() => this.onmessage?.({ data: JSON.stringify({ channels: [{
          channel_id: 'voice-1', participants: [
            { account_id: 'alex-3', display_name: 'Alex', screen_sharing: true, microphone_muted: true },
            { account_id: 'daria-2', display_name: 'Daria', screen_sharing: false, microphone_muted: false },
            { account_id: 'max-7', display_name: 'Max', screen_sharing: false, microphone_muted: false },
            { account_id: 'egor-2', display_name: 'Егор', screen_sharing: false, microphone_muted: false },
          ],
        }] }) }), 30)
      }
      addEventListener() {}
      close() {}
    }
  })
}

export async function connectReferenceVoiceStore(page) {
  await page.evaluate(async () => {
    const { useVoiceConnectionStore } = await import('/src/voice/connection_store.ts')
    const store = useVoiceConnectionStore()
    Object.defineProperty(store, 'voiceVolumeParticipants', { configurable: true, get: () => [
      { id: 'alex-3', accountId: 'alex-3', name: 'Alex', microphoneMuted: false, speaking: true, volume: 100 },
      { id: 'daria-2', accountId: 'daria-2', name: 'Daria', microphoneMuted: false, speaking: false, volume: 100 },
      { id: 'max-7', accountId: 'max-7', name: 'Max', microphoneMuted: false, speaking: false, volume: 100 },
    ] })
    Object.defineProperty(store, 'screenViewerCards', { configurable: true, get: () => [
      { id: 'alex-stream', accountId: 'alex-3', hasAudio: false, isLocal: false, participantId: 'alex-3', participantName: 'Alex' },
    ] })
    store.active = { channelId: 'voice-1', room: { onNoiseSuppressionState: () => () => {} } }
    store.state = 'CONNECTED'
    store.connectionQuality = 'GOOD'
  })
}

export async function connectReferenceMediaStore(page, sceneBase64, selectScreen, ownScreenSharing = false) {
  await connectReferenceVoiceStore(page)
  await page.evaluate(async ({ sceneBase64, selectScreen, ownScreenSharing }) => {
    const { useVoiceConnectionStore } = await import('/src/voice/connection_store.ts')
    const store = useVoiceConnectionStore()
    let sample = 0
    const cards = [
      { id: 'alex-stream', accountId: 'alex-3', participantId: 'alex-3', participantName: 'Alex', hasAudio: true, isLocal: false, targetProfile: 'P1440_60', thumbnailUrl: `data:image/png;base64,${sceneBase64}`, readReceiverStats: async () => { sample += 1; return { bytesReceived: sample * 2_100_000, framesDecoded: sample * 120, framesDropped: 0, packetsReceived: sample * 10_000, packetsLost: sample * 20, jitter: 0.004, timestamp: Date.now() } } },
      { id: 'max-stream', accountId: 'max-7', participantId: 'max-7', participantName: 'Max', hasAudio: false, isLocal: false, targetProfile: 'P1080_30' },
    ]
    Object.defineProperty(store, 'screenViewerCards', { configurable: true, get: () => cards })
    const source = new Image()
    source.src = `data:image/png;base64,${sceneBase64}`
    await source.decode()
    const canvas = document.createElement('canvas')
    canvas.width = 1280; canvas.height = 443
    canvas.getContext('2d')?.drawImage(source, 0, 0, canvas.width, canvas.height)
    const stream = canvas.captureStream(60)
    window.__designV2Paint = setInterval(() => canvas.getContext('2d')?.drawImage(source, 0, 0, canvas.width, canvas.height), 1000 / 60)
    store.selectedScreenAudioVolume = 65
    if (ownScreenSharing) { store.screenState = 'SHARING'; store.screenProfile = 'P1440_60' }
    window.__designV2Stream = stream
    store.selectScreenStream = (id, video) => {
      store.selectedScreenStreamId = id
      if (video && id) { video.srcObject = stream; void video.play().catch(() => {}) }
    }
    if (selectScreen) store.selectedScreenStreamId = 'alex-stream'
  }, { sceneBase64, selectScreen, ownScreenSharing })
  if (selectScreen) {
    await page.locator('.screen-player').waitFor({ state: 'visible' })
    await page.locator('.screen-player').evaluate((video) => {
      // The fixture provides a real MediaStream track without using LiveKit credentials.
      video.srcObject = window.__designV2Stream
      void video.play().catch(() => {})
    })
  }
}
