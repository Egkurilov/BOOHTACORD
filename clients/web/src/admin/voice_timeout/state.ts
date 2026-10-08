import { ref } from 'vue'
import { reasons, voiceTimeout, VoiceTimeoutError, type Method, type Reason, type TimeoutInput, type VoiceTimeoutState } from './client'

type Gateway = (account: string, method: Method, input?: TimeoutInput, signal?: AbortSignal) => Promise<VoiceTimeoutState>
export function createVoiceTimeoutState(account: string, gateway: Gateway = voiceTimeout, now = Date.now) {
  const value = ref<VoiceTimeoutState | null>(null), busy = ref(false), error = ref<string | null>(null)
  let disposed = false, epoch = 0, controller: AbortController | null = null
  async function run(method: Method, input?: TimeoutInput): Promise<void> {
    if (disposed || busy.value) return
    const current = ++epoch; controller = new AbortController(); busy.value = true; error.value = null
    try {
      const result = await gateway(account, method, input, controller.signal)
      if (!disposed && current === epoch) value.value = result
    } catch (cause) {
      if (!disposed && current === epoch) {
        value.value = null
        error.value = cause instanceof VoiceTimeoutError ? cause.message : 'Не удалось обновить ограничение голоса.'
      }
    } finally { if (!disposed && current === epoch) { busy.value = false; controller = null } }
  }
  function requireLoaded(): boolean {
    if (value.value) return true
    error.value = 'Сначала загрузите актуальное ограничение голоса.'; return false
  }
  async function set(minutes: number, reason: Reason): Promise<void> {
    if (!requireLoaded()) return
    if (![5, 15, 60, 240, 1440].includes(minutes) || !reasons.includes(reason)) {
      error.value = 'Выберите срок и причину из списка.'; return
    }
    await run('PUT', { expires_at: new Date(now() + minutes * 60000).toISOString(), reason_code: reason })
  }
  async function clear(): Promise<void> { if (requireLoaded()) await run('DELETE') }
  function dispose(): void {
    disposed = true; epoch++; controller?.abort(); controller = null
    value.value = null; error.value = null; busy.value = false
  }
  return { value, busy, error, load: () => run('GET'), set, clear, dispose }
}
