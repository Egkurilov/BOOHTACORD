interface DirectMessageRefresh {
  directMessageId: string | null
  error: string | null
  refreshNavigation(): Promise<void>
  refreshHistory(): Promise<void>
}

export async function refreshDirectMessageHint(store: DirectMessageRefresh, directMessageID: string): Promise<void> {
  await store.refreshNavigation()
  if (store.error) throw new Error(store.error)
  if (store.directMessageId !== directMessageID) return
  await store.refreshHistory()
  if (store.error) throw new Error(store.error)
}
