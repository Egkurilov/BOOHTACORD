import { describe, expect, it } from 'vitest'

import { createCategoryNavigationPreferences, filterNavigationCategories } from './preferences'

function memoryStorage(): Storage {
  const values = new Map<string, string>()
  return {
    get length() { return values.size },
    clear: () => values.clear(),
    getItem: key => values.get(key) ?? null,
    key: index => [...values.keys()][index] ?? null,
    removeItem: key => { values.delete(key) },
    setItem: (key, value) => { values.set(key, value) },
  }
}

const categories = [
  { id: 'games', name: 'Игры', channels: [{ id: 'voice-a', name: 'Общий голос', kind: 'VOICE' }, { id: 'text-a', name: 'Общий чат', kind: 'TEXT' }] },
  { id: 'empty', name: 'Пустой раздел', channels: [] },
]

describe('category navigation preferences', () => {
  it('isolates local favorites and collapsed categories by account and origin', () => {
    const storage = memoryStorage()
    const first = createCategoryNavigationPreferences('account-a', 'https://guild.example', storage)
    first.setFavorite('voice-a', true)
    first.toggleCollapsed('games')
    first.pruneCollapsed(new Set(['games', 'empty']))

    const sameScope = createCategoryNavigationPreferences('account-a', 'https://guild.example', storage)
    const otherAccount = createCategoryNavigationPreferences('account-b', 'https://guild.example', storage)
    const otherOrigin = createCategoryNavigationPreferences('account-a', 'https://other.example', storage)
    expect(sameScope.favoriteIds()).toEqual(['voice-a'])
    expect(sameScope.isCollapsed('games')).toBe(true)
    expect(otherAccount.favoriteIds()).toEqual([])
    expect(otherAccount.isCollapsed('games')).toBe(false)
    expect(otherOrigin.favoriteIds()).toEqual([])
  })

  it('drops collapsed state for deleted categories while retaining empty categories', () => {
    const preferences = createCategoryNavigationPreferences('account-a', 'https://guild.example', memoryStorage())
    preferences.toggleCollapsed('empty')
    preferences.pruneCollapsed(new Set(['empty']))
    expect(preferences.isCollapsed('empty')).toBe(true)
    preferences.pruneCollapsed(new Set())
    expect(preferences.isCollapsed('empty')).toBe(false)
  })

  it('removes archived or unknown channels from favorites without changing topology', () => {
    const preferences = createCategoryNavigationPreferences('account-a', 'https://guild.example', memoryStorage())
    preferences.setFavorite('text-a', true)
    preferences.setFavorite('archived-channel', true)
    preferences.pruneFavorites(new Set(categories.flatMap(category => category.channels.map(channel => channel.id))))
    expect(preferences.favoriteIds()).toEqual(['text-a'])
    expect(categories[0].channels).toHaveLength(2)
  })

  it('keeps empty categories visible without a query and filters channels quickly by name or category', () => {
    expect(filterNavigationCategories(categories, '').map(category => category.id)).toEqual(['games', 'empty'])
    expect(filterNavigationCategories(categories, 'ГОЛОС').map(category => category.channels.map(channel => channel.id))).toEqual([['voice-a']])
    expect(filterNavigationCategories(categories, 'пустой').map(category => category.id)).toEqual(['empty'])
  })

  it('ignores malformed or oversized saved state and survives unavailable storage', () => {
    const storage = memoryStorage()
    const state = createCategoryNavigationPreferences('account-a', 'https://guild.example', storage)
    state.setFavorite('voice-a', true)
    expect(state.favoriteIds()).toEqual(['voice-a'])
    const blockedStorage = { ...memoryStorage(), getItem: () => { throw new Error('denied') }, setItem: () => { throw new Error('denied') } } as Storage
    const fallback = createCategoryNavigationPreferences('account-a', 'https://guild.example', blockedStorage)
    fallback.setFavorite('voice-a', true)
    expect(fallback.favoriteIds()).toEqual(['voice-a'])
    const corrupt = memoryStorage()
    const corruptState = createCategoryNavigationPreferences('account-a', 'https://guild.example', corrupt)
    corrupt.setItem('boohtacord:navigation:https%3A%2F%2Fguild.example:account-a:v1', '{')
    expect(corruptState.favoriteIds()).toEqual([])
  })
})
