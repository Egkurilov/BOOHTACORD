import { ref } from 'vue'

export function useCategoryDisclosure() {
  const collapsed = ref(new Set<string>())
  function isOpen(categoryId: string): boolean { return !collapsed.value.has(categoryId) }
  function toggle(categoryId: string): void {
    const next = new Set(collapsed.value)
    if (next.has(categoryId)) next.delete(categoryId)
    else next.add(categoryId)
    collapsed.value = next
  }
  return { isOpen, toggle }
}
