import { shallowRef, ref } from 'vue'

interface ContextItem { id: string; deleted: boolean; createdAt?: string }
type ContextStatus = 'idle' | 'loading' | 'ready' | 'deleted' | 'unavailable' | 'error'
interface Page<Item> { messages: Item[]; nextCursor?: string }

export function createSearchContextController<Item extends ContextItem>(load: (messageId: string) => Promise<Page<Item>>,
  paging: { newer?: (id: string) => Promise<Page<Item>>; older?: (id: string) => Promise<Page<Item>> } = {}) {
  const messages = shallowRef<Item[]>([])
  const status = ref<ContextStatus>('idle')
  const hasNewer = ref(false), olderCursor = ref<string | undefined>(), pagingError = ref(''), pagingPending = ref(false)
  let newerCursor = ''
  let sequence = 0

  async function open(messageId: string): Promise<void> {
    const current = ++sequence
    messages.value = []
    hasNewer.value = false; olderCursor.value = undefined; pagingError.value = ''; pagingPending.value = false
    status.value = 'loading'
    try {
      const page = await load(messageId)
      if (current !== sequence) return
      if (page.messages[0]?.id !== messageId) { status.value = 'unavailable'; return }
      messages.value = page.messages
      newerCursor = messageId; hasNewer.value = Boolean(paging.newer); olderCursor.value = page.nextCursor
      status.value = page.messages[0].deleted ? 'deleted' : 'ready'
    } catch {
      if (current === sequence) status.value = 'error'
    }
  }

  async function append(direction: 'newer' | 'older'): Promise<void> {
    const fetch = paging[direction], cursor = direction === 'newer' ? newerCursor : olderCursor.value
    if (!fetch || !cursor || pagingPending.value || (direction === 'newer' && !hasNewer.value)) return
    const current = sequence
    pagingPending.value = true; pagingError.value = ''
    try {
      const page = await fetch(cursor)
      if (current !== sequence) return
      const merged = new Map(messages.value.map(item => [item.id, item]))
      for (const item of page.messages) merged.set(item.id, item)
      messages.value = [...merged.values()].sort((a, b) => (b.createdAt ?? '').localeCompare(a.createdAt ?? '') || b.id.localeCompare(a.id))
      if (direction === 'newer') { newerCursor = page.nextCursor ?? newerCursor; hasNewer.value = Boolean(page.nextCursor) }
      else olderCursor.value = page.nextCursor
    } catch { if (current === sequence) pagingError.value = 'Не удалось загрузить страницу. Повторите попытку.' }
    finally { if (current === sequence) pagingPending.value = false }
  }
  function clear(): void { sequence++; messages.value = []; status.value = 'idle'; hasNewer.value = false; pagingPending.value = false }

  return { messages, status, hasNewer, olderCursor, pagingPending, pagingError, open, clear,
    loadNewer: () => append('newer'), loadOlder: () => append('older') }
}
