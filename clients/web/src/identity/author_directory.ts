import { tracedFetch } from '../telemetry/client_tracing'
import { defineStore } from 'pinia'
import { ref } from 'vue'

import { apiBaseUrl } from '../config/runtime'
import { loadMember, type OwnProfile, type ProfileRequest } from './profile_client'

interface AuthorEntry { displayName: string; hasAvatar: boolean; checkedAt: number; verified: boolean; revision: number }

const freshForMs = 60_000
const fallbackName = 'Участник'

export const useAuthorDirectory = defineStore('author-directory', () => {
  const authors = ref<Record<string, AuthorEntry>>({})
  const knownIds = new Set<string>()
  const inFlight = new Map<string, { generation: number; task: Promise<void> }>()
  const lookupGenerations = new Map<string, number>()
  let refreshTask: Promise<void> | null = null

  function displayName(id: string): string { return authors.value[id]?.displayName || fallbackName }
  function verifiedDisplayName(id: string): string | null { const entry = authors.value[id]; return entry?.verified ? entry.displayName : null }
  function avatarUrl(id: string): string | undefined {
    const entry = authors.value[id]
    return entry?.hasAvatar ? `${apiBaseUrl}/members/${encodeURIComponent(id)}/avatar${entry.revision ? `?revision=${entry.revision}` : ''}` : undefined
  }

  function ensure(id: string, request: ProfileRequest = tracedFetch, force = false): Promise<void> {
    if (!id || id === 'Вы') return Promise.resolve()
    knownIds.add(id)
    const current = authors.value[id]
    if (!force && current && Date.now() - current.checkedAt < freshForMs) return Promise.resolve()
    const generation = lookupGenerations.get(id) ?? 0
    const running = inFlight.get(id)
    if (running?.generation === generation) return running.task
    const task = (async () => {
      try {
        const member = await loadMember(id, request)
        if (member.user_id !== id) throw new Error('Некорректный участник.')
        if ((lookupGenerations.get(id) ?? 0) !== generation) return
        if (member.profile_revision !== undefined && member.profile_revision < (authors.value[id]?.revision ?? 0)) return
        const name = member.display_name.trim()
        authors.value[id] = { displayName: name || fallbackName, hasAvatar: Boolean(member.avatar_url), checkedAt: Date.now(), verified: Boolean(name), revision: member.profile_revision ?? 0 }
      } catch {
        if ((lookupGenerations.get(id) ?? 0) !== generation) return
        const previous = authors.value[id]
        authors.value[id] = previous ? { ...previous, checkedAt: Date.now(), verified: false } : { displayName: fallbackName, hasAvatar: false, checkedAt: Date.now(), verified: false, revision: 0 }
      }
    })()
    inFlight.set(id, { generation, task })
    void task.finally(() => {
      if (inFlight.get(id)?.task === task) inFlight.delete(id)
    })
    return task
  }

  function acceptOwnProfile(profile: OwnProfile): void {
    knownIds.add(profile.account_id)
    lookupGenerations.set(profile.account_id, (lookupGenerations.get(profile.account_id) ?? 0) + 1)
    const name = profile.display_name.trim()
    authors.value[profile.account_id] = { displayName: name || fallbackName, hasAvatar: Boolean(profile.avatar_url), checkedAt: Date.now(), verified: Boolean(name), revision: profile.profile_revision ?? 0 }
  }

  function invalidate(id: string, revision: number, request: ProfileRequest = tracedFetch): Promise<void> {
    if (!id || !Number.isSafeInteger(revision) || revision < 1) return Promise.resolve()
    if ((authors.value[id]?.revision ?? 0) >= revision) return Promise.resolve()
    knownIds.add(id)
    lookupGenerations.set(id, (lookupGenerations.get(id) ?? 0) + 1)
    return ensure(id, request, true)
  }

  function refreshKnown(request: ProfileRequest = tracedFetch): Promise<void> {
    if (refreshTask) return refreshTask
    const ids = [...knownIds]
    for (const id of ids) lookupGenerations.set(id, (lookupGenerations.get(id) ?? 0) + 1)
    const task = Promise.all(ids.map((id) => ensure(id, request, true))).then(() => undefined)
    const tracked = task.finally(() => {
      if (refreshTask === tracked) refreshTask = null
    })
    refreshTask = tracked
    return tracked
  }

  return { acceptOwnProfile, avatarUrl, displayName, ensure, invalidate, refreshKnown, verifiedDisplayName }
})
