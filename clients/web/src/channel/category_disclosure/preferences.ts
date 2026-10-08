type StoragePort = Pick<Storage, 'getItem' | 'setItem'>
type NavigationPreferences = { favorites: string[]; collapsed: string[] }
type NavigationChannel = { id: string; name: string; kind: string }
type NavigationCategory<T extends NavigationChannel = NavigationChannel> = { id: string; name: string; channels: T[] }

const emptyPreferences = (): NavigationPreferences => ({ favorites: [], collapsed: [] })
const validIds = (value: unknown): value is string[] => Array.isArray(value)
  && value.length <= 500
  && value.every(id => typeof id === 'string' && /^[a-zA-Z0-9:_-]{1,100}$/.test(id))

function preferenceKey(accountId: string, origin: string): string {
  return `boohtacord:navigation:${encodeURIComponent(origin)}:${encodeURIComponent(accountId)}:v1`
}

export function createCategoryNavigationPreferences(accountId: string, origin: string, storage?: StoragePort | null) {
  const key = preferenceKey(accountId, origin)
  let memory = emptyPreferences()
  function read(): NavigationPreferences {
    try {
      const raw = storage?.getItem(key)
      if (!raw || raw.length > 32768) return memory
      const value: unknown = JSON.parse(raw)
      if (!value || typeof value !== 'object' || Array.isArray(value)) return memory
      const candidate = value as Partial<NavigationPreferences>
      if (!validIds(candidate.favorites) || !validIds(candidate.collapsed)) return memory
      memory = { favorites: [...new Set(candidate.favorites)], collapsed: [...new Set(candidate.collapsed)] }
    } catch { /* Local navigation remains usable when browser storage is blocked. */ }
    return memory
  }
  function write(next: NavigationPreferences): void {
    memory = next
    try { storage?.setItem(key, JSON.stringify(next)) } catch { /* Keep preferences for this mounted session. */ }
  }
  function favoriteIds(): string[] { return [...read().favorites] }
  function setFavorite(channelId: string, favorite: boolean): void {
    if (!/^[a-zA-Z0-9:_-]{1,100}$/.test(channelId)) return
    const current = read()
    const favorites = favorite ? [...new Set([...current.favorites, channelId])] : current.favorites.filter(id => id !== channelId)
    write({ ...current, favorites })
  }
  function isCollapsed(categoryId: string): boolean { return read().collapsed.includes(categoryId) }
  function toggleCollapsed(categoryId: string): void {
    if (!/^[a-zA-Z0-9:_-]{1,100}$/.test(categoryId)) return
    const current = read()
    const collapsed = current.collapsed.includes(categoryId) ? current.collapsed.filter(id => id !== categoryId) : [...current.collapsed, categoryId]
    write({ ...current, collapsed })
  }
  function pruneFavorites(validChannelIds: Set<string>): void {
    const current = read()
    const favorites = current.favorites.filter(id => validChannelIds.has(id))
    if (favorites.length !== current.favorites.length) write({ ...current, favorites })
  }
  function pruneCollapsed(validCategoryIds: Set<string>): void {
    const current = read()
    const collapsed = current.collapsed.filter(id => validCategoryIds.has(id))
    if (collapsed.length !== current.collapsed.length) write({ ...current, collapsed })
  }
  return { favoriteIds, setFavorite, isCollapsed, toggleCollapsed, pruneFavorites, pruneCollapsed }
}

export function filterNavigationCategories<C extends NavigationCategory>(categories: C[], query: string): C[] {
  const normalized = query.trim().toLocaleLowerCase()
  if (!normalized) return categories
  return categories.flatMap(category => {
    if (category.name.toLocaleLowerCase().includes(normalized)) return [category]
    const channels = category.channels.filter(channel => channel.name.toLocaleLowerCase().includes(normalized))
    return channels.length ? [{ ...category, channels } as C] : []
  })
}
