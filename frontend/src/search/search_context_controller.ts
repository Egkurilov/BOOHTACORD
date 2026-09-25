import { shallowRef, ref } from 'vue'

interface ContextItem { id: string; deleted: boolean }
type ContextStatus = 'idle' | 'loading' | 'ready' | 'deleted' | 'unavailable' | 'error'

export function createSearchContextController<Item extends ContextItem>(load: (messageId: string) => Promise<{ messages: Item[] }>) {
  const messages = shallowRef<Item[]>([])
  const status = ref<ContextStatus>('idle')
  let sequence = 0

  async function open(messageId: string): Promise<void> {
    const current = ++sequence
    messages.value = []
    status.value = 'loading'
    try {
      const page = await load(messageId)
      if (current !== sequence) return
      if (page.messages[0]?.id !== messageId) { status.value = 'unavailable'; return }
      messages.value = page.messages
      status.value = page.messages[0].deleted ? 'deleted' : 'ready'
    } catch {
      if (current === sequence) status.value = 'error'
    }
  }

  function clear(): void { sequence++; messages.value = []; status.value = 'idle' }

  return { messages, status, open, clear }
}
