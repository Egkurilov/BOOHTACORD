import { defineStore } from 'pinia'
import { ref } from 'vue'

export type AttachmentFilter = 'any' | 'with' | 'without'

export const useSearchFilters = defineStore('search-filters', () => {
  const authorId = ref('')
  const attachment = ref<AttachmentFilter>('any')

  function reset(): void {
    authorId.value = ''
    attachment.value = 'any'
  }

  return { authorId, attachment, reset }
})
