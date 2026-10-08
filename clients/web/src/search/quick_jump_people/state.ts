import { ref } from 'vue'
import { loadDirectMessageCandidates, type DirectMessageCandidate, type DirectMessageCandidatePage } from '../../direct_message/direct_message_candidate_client'

export function createQuickJumpPeople(load: (after?: string) => Promise<DirectMessageCandidatePage> = loadDirectMessageCandidates) {
  const people = ref<DirectMessageCandidate[]>([]), after = ref<string>(), loading = ref(false), error = ref('')
  let sequence = 0, disposed = false
  async function fetchPage(append: boolean): Promise<void> {
    if (disposed || loading.value || (append && !after.value)) return
    const current = ++sequence
    loading.value = true; error.value = ''
    try {
      const page = await load(append ? after.value : undefined)
      if (disposed || current !== sequence) return
      people.value = [...new Map([...(append ? people.value : []), ...page.candidates].map(person => [person.id, person])).values()]
      after.value = page.nextAfter
    } catch { if (!disposed && current === sequence) error.value = 'Не удалось обновить участников. Повторите попытку.' }
    finally { if (!disposed && current === sequence) loading.value = false }
  }
  return { people, after, loading, error, refresh: () => fetchPage(false), next: () => fetchPage(true),
    dispose() { disposed = true; sequence++; people.value = []; after.value = undefined; loading.value = false; error.value = '' } }
}
