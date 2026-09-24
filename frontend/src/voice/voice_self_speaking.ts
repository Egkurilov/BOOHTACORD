import { ref } from 'vue'

export interface VoiceActivitySource {
  isSpeaking?(id: string): boolean
  onChange?(listener: () => void): () => void
}

export interface VoiceActivitySession {
  remoteVoices(): VoiceActivitySource | null
}

export function createVoiceSelfSpeaking(session: VoiceActivitySession) {
  const selfSpeaking = ref(false)
  let accountId: string | null = null
  let unsubscribe: () => void = () => undefined

  function sync(): void {
    selfSpeaking.value = accountId ? session.remoteVoices()?.isSpeaking?.(accountId) ?? false : false
  }

  function stop(): void {
    unsubscribe()
    unsubscribe = () => undefined
    accountId = null
    selfSpeaking.value = false
  }

  function start(authenticatedAccountId: string): void {
    stop()
    accountId = authenticatedAccountId
    unsubscribe = session.remoteVoices()?.onChange?.(sync) ?? (() => undefined)
    sync()
  }

  return { selfSpeaking, start, stop }
}
