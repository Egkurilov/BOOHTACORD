import { defineStore } from 'pinia'
import { ref } from 'vue'

export interface SearchTarget { kind: 'CHANNEL' | 'DIRECT_MESSAGE'; conversationId: string; messageId: string }

export const useSearchTargetStore = defineStore('search-target', () => {
  const target = ref<SearchTarget | null>(null)
  function open(next: SearchTarget): void { target.value = next }
  function clear(): void { target.value = null }
  function clearFor(kind: SearchTarget['kind'], conversationId: string): void {
    if (target.value?.kind === kind && target.value.conversationId === conversationId) clear()
  }
  return { target, open, clear, clearFor }
})
