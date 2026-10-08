import { ref, shallowRef, watch } from 'vue'

import { createCategoryNavigationPreferences } from './preferences'

type StoragePort = Pick<Storage, 'getItem' | 'setItem'>

export function useCategoryDisclosure(accountId: string | (() => string), origin = appOrigin(), storage: StoragePort | null = appStorage()) {
  const currentAccount = typeof accountId === 'function' ? accountId : () => accountId
  const preferences = shallowRef(createCategoryNavigationPreferences(currentAccount(), origin, storage))
  const revision = ref(0)
  if (typeof accountId === 'function') watch(accountId, value => { preferences.value = createCategoryNavigationPreferences(value, origin, storage); revision.value++ })
  function isOpen(categoryId: string): boolean { revision.value; return !preferences.value.isCollapsed(categoryId) }
  function toggle(categoryId: string): void {
    preferences.value.toggleCollapsed(categoryId)
    revision.value++
  }
  function isFavorite(channelId: string): boolean { revision.value; return preferences.value.favoriteIds().includes(channelId) }
  function toggleFavorite(channelId: string): void {
    preferences.value.setFavorite(channelId, !preferences.value.favoriteIds().includes(channelId))
    revision.value++
  }
  function favoriteIds(): string[] { revision.value; return preferences.value.favoriteIds() }
  function pruneFavorites(validChannelIds: Set<string>): void { preferences.value.pruneFavorites(validChannelIds); revision.value++ }
  function pruneCollapsed(validCategoryIds: Set<string>): void { preferences.value.pruneCollapsed(validCategoryIds); revision.value++ }
  return { isOpen, toggle, isFavorite, toggleFavorite, favoriteIds, pruneFavorites, pruneCollapsed }
}

function appOrigin(): string { return typeof window === 'undefined' ? '' : window.location.origin }
function appStorage(): StoragePort | null { try { return typeof window === 'undefined' ? null : window.localStorage } catch { return null } }
