interface TopologyRefresh { error: string | null; refresh(): Promise<void> }

export async function refreshTopologyHint(store: TopologyRefresh): Promise<void> {
  await store.refresh()
  if (store.error) throw new Error(store.error)
}
