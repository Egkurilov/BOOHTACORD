import { ref } from 'vue'
import { loadOwnSessions, revokeOtherSessions, revokeOwnSession, SessionRequestError, type OwnSession, type OwnSessionPage } from './client'
interface SessionsApi { read(cursor?: string): Promise<OwnSessionPage>; revoke(accountId: string, id: string): Promise<void>; revokeOthers(accountId: string): Promise<void> }
const listeners = new Set<() => void>()
export function notifyOwnSessionsChanged(): void { for (const listener of listeners) listener() }
export function createOwnSessionsState(api: SessionsApi = { read: loadOwnSessions, revoke: revokeOwnSession, revokeOthers: revokeOtherSessions }) {
  const items = ref<OwnSession[]>([]), error = ref<string | null>(null), busy = ref(false), nextCursor = ref<string | null>(null), expired = ref(false)
  let account = '', generation = 0, closed = false
  function reset(): void { generation++; items.value = []; error.value = null; busy.value = false; nextCursor.value = null; expired.value = false }
  function setAccount(value: string): void { if (value !== account) { reset(); account = value } }
  async function run(action: () => Promise<OwnSessionPage>, append: boolean): Promise<void> {
    if (!account || closed || busy.value) return
    const token = generation, owner = account
    busy.value = true; error.value = null
    try {
      const page = await action()
      if (closed || token !== generation) return
      if (page.accountId !== owner) throw new SessionRequestError(409, 'SESSION_ACCOUNT_CHANGED')
      items.value = append ? [...new Map([...items.value, ...page.sessions].map(row => [row.id, row])).values()] : page.sessions
      nextCursor.value = page.nextCursor
    } catch (cause) {
      if (closed || token !== generation) return
      error.value = cause instanceof Error ? cause.message : 'Не удалось обновить сеансы.'
      if (cause instanceof SessionRequestError && (cause.status === 401 || cause.code === 'SESSION_ACCOUNT_CHANGED')) {
        items.value = []; nextCursor.value = null; expired.value = true
      }
    } finally { if (!closed && token === generation) busy.value = false }
  }
  function refresh(): Promise<void> { return run(() => api.read(), false) }
  function more(): Promise<void> { const cursor = nextCursor.value; return cursor ? run(() => api.read(cursor), true) : Promise.resolve() }
  async function mutate(action: (owner: string) => Promise<void>): Promise<void> {
    const owner = account, token = generation
    await run(async () => {
      await action(owner)
      if (closed || token !== generation) return { accountId: owner, sessions: [], nextCursor: null }
      return api.read()
    }, false)
  }
  function revoke(id: string): Promise<void> {
    if (!items.value.some(row => row.id === id && !row.current)) return Promise.resolve()
    return mutate(owner => api.revoke(owner, id))
  }
  function revokeOthers(): Promise<void> { return mutate(owner => api.revokeOthers(owner)) }
  const changed = () => { void refresh() }
  listeners.add(changed)
  function stopListening(): void { listeners.delete(changed) }
  function close(): void { closed = true; reset(); stopListening() }
  return { items, error, busy, expired, nextCursor, setAccount, refresh, more, revoke, revokeOthers, close, stopListening }
}
