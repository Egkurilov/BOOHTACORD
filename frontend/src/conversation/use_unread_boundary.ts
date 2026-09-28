import { nextTick, ref, watch, type Ref } from 'vue'

export function useUnreadBoundary(
  conversationId: () => string,
  firstUnread: Ref<string | undefined>,
  onLatest: () => void,
) {
  const unreadBoundary = ref('')
  const unreadContextOpen = ref(false)
  const readUnlocked = ref(false)

  watch(conversationId, () => {
    unreadBoundary.value = firstUnread.value ?? ''
    unreadContextOpen.value = false
    readUnlocked.value = false
  }, { immediate: true })
  watch(firstUnread, (id) => {
    if (id && !readUnlocked.value && !unreadBoundary.value) unreadBoundary.value = id
  })

  function showUnread(): void { unreadContextOpen.value = true }
  function continueAtLatest(): void {
    unreadContextOpen.value = false
    readUnlocked.value = true
    void nextTick(onLatest)
  }

  return { unreadBoundary, unreadContextOpen, readUnlocked, showUnread, continueAtLatest }
}
