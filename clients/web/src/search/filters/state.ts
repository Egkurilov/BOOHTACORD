import { defineStore } from 'pinia'
import { ref } from 'vue'

export type AttachmentFilter = 'any' | 'with' | 'without'

export const useSearchFilters = defineStore('search-filters', () => {
  const authorId = ref('')
  const attachment = ref<AttachmentFilter>('any')
  const dateFrom = ref('')
  const dateTo = ref('')

  function reset(): void {
    authorId.value = ''
    attachment.value = 'any'
    dateFrom.value = ''
    dateTo.value = ''
  }

  return { authorId, attachment, dateFrom, dateTo, reset }
})
