import { tracedFetch } from '../telemetry/client_tracing'
import { defineStore } from 'pinia'
import { ref } from 'vue'

import { apiBaseUrl } from '../config/runtime'
import { loadMember, type OwnProfile, type ProfileRequest } from './profile_client'

interface AuthorEntry { displayName: string; hasAvatar: boolean; checkedAt: number; verified: boolean }

const freshForMs = 60_000
const fallbackName = 'Участник'

export const useAuthorDirectory = defineStore('author-directory', () => {
  const authors = ref<Record<string, AuthorEntry>>({})
  const inFlight = new Map<string, Promise<void>>()
  const ownRevisions = new Map<string, number>()

  function displayName(id: string): string { return authors.value[id]?.displayName || fallbackName }
  function verifiedDisplayName(id: string): string | null { const entry = authors.value[id]; return entry?.verified ? entry.displayName : null }
  function avatarUrl(id: string): string | undefined {
    return authors.value[id]?.hasAvatar ? `${apiBaseUrl}/members/${encodeURIComponent(id)}/avatar` : undefined
  }

  function ensure(id: string, request: ProfileRequest = tracedFetch, force = false): Promise<void> {
    if (!id || id === 'Вы') return Promise.resolve()
    const current = authors.value[id]
    if (!force && current && Date.now() - current.checkedAt < freshForMs) return Promise.resolve()
    const running = inFlight.get(id)
    if (running) return running
    const revision = ownRevisions.get(id) ?? 0
    const task = (async () => {
      try {
        const member = await loadMember(id, request)
        if (member.user_id !== id) throw new Error('Некорректный участник.')
        if ((ownRevisions.get(id) ?? 0) !== revision) return
        const name = member.display_name.trim()
        authors.value[id] = { displayName: name || fallbackName, hasAvatar: Boolean(member.avatar_url), checkedAt: Date.now(), verified: Boolean(name) }
      } catch {
        if ((ownRevisions.get(id) ?? 0) !== revision) return
        const previous = authors.value[id]
        authors.value[id] = previous ? { ...previous, checkedAt: Date.now(), verified: false } : { displayName: fallbackName, hasAvatar: false, checkedAt: Date.now(), verified: false }
      }
    })()
    inFlight.set(id, task)
    void task.finally(() => inFlight.delete(id))
    return task
  }

  function acceptOwnProfile(profile: OwnProfile): void {
    ownRevisions.set(profile.account_id, (ownRevisions.get(profile.account_id) ?? 0) + 1)
    const name = profile.display_name.trim()
    authors.value[profile.account_id] = { displayName: name || fallbackName, hasAvatar: Boolean(profile.avatar_url), checkedAt: Date.now(), verified: Boolean(name) }
  }

  async function refreshKnown(request: ProfileRequest = tracedFetch): Promise<void> {
    await Promise.all(Object.keys(authors.value).map((id) => ensure(id, request, true)))
  }

  return { acceptOwnProfile, avatarUrl, displayName, ensure, refreshKnown, verifiedDisplayName }
})
