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
      { id: 'alex-3', accountId: 'alex-3', name: 'Alex', microphoneMuted: true, speaking: false, volume: 100 },
      { id: 'daria-2', accountId: 'daria-2', name: 'Daria', microphoneMuted: false, speaking: false, volume: 100 },
      { id: 'max-7', accountId: 'max-7', name: 'Max', microphoneMuted: false, speaking: false, volume: 100 },
    ] })
    store.active = { channelId: 'voice-1', room: { onNoiseSuppressionState: () => () => {} } }
    store.state = 'CONNECTED'
    store.connectionQuality = 'GOOD'
  })
}
