import { defineStore } from 'pinia'
import { computed, ref } from 'vue'

import { loadMembers, type GuildMember, type ProfileRequest } from './profile_client'

function keepLatest(incoming: GuildMember[], current: GuildMember[]): GuildMember[] {
  const previous = new Map(current.map((member) => [member.user_id, member]))
  return incoming.map((member) => {
    const latest = previous.get(member.user_id)
    return latest && (latest.profile_revision ?? 0) > (member.profile_revision ?? 0)
      ? { ...member, display_name: latest.display_name, avatar_url: latest.avatar_url, profile_revision: latest.profile_revision }
      : member
  })
}

export const useMemberDirectory = defineStore('member-directory', () => {
  const members = ref<GuildMember[]>([])
  const cursor = ref<string | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)
  let running: Promise<void> | null = null

  const byId = computed(() => Object.fromEntries(members.value.map((member) => [member.user_id, member])))

  function load(cursorValue?: string, request?: ProfileRequest): Promise<void> {
    if (running) return running
    loading.value = true
    error.value = null
    const current = members.value
    const task = loadMembers(cursorValue, request).then((page) => {
      const incoming = cursorValue ? [...members.value, ...page.members] : page.members
      members.value = keepLatest(incoming, current)
      cursor.value = page.next_cursor ?? null
    }).catch((cause: unknown) => {
      error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить участников.'
    }).finally(() => {
      loading.value = false
      if (running === tracked) running = null
    })
    const tracked = task
    running = tracked
    return tracked
  }

  function refresh(request?: ProfileRequest): Promise<void> { return load(undefined, request) }
  async function invalidate(request?: ProfileRequest): Promise<void> {
    const loadedCount = members.value.length
    if (running) await running
    await refresh(request)
    while (cursor.value && members.value.length < loadedCount) await loadNext(request)
  }
  function loadNext(request?: ProfileRequest): Promise<void> {
    return cursor.value ? load(cursor.value, request) : Promise.resolve()
  }

  return { byId, cursor, error, invalidate, load, loadNext, loading, members, refresh }
})
