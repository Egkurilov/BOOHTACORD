# Direct-message client and store Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a typed, same-origin frontend read model for the existing private direct-message list and message-history endpoints, ready for a later DM surface.

**Architecture:** `direct_message_client.ts` owns endpoint URLs, response validation and API-shaped value objects.  `direct_message_store.ts` owns the private list, the selected DM history and stale-request suppression; it deliberately does not send a read cursor because only a future visible, selected DM view can prove the REQ-CHAT-02 visibility precondition.  This changes no ACL and displays no UI by itself.

**Tech Stack:** Vue 3, TypeScript, Pinia, Vite, Vitest.

---

### Task 1: Typed direct-message read client

**Files:**
- Create: `frontend/src/direct_message/direct_message_client.spec.ts`
- Create: `frontend/src/direct_message/direct_message_client.ts`

- [x] **Step 1: Write failing client-contract tests**

```ts
import { describe, expect, it, vi } from 'vitest'

import { loadDirectMessageHistory, loadDirectMessages } from './direct_message_client'

const directMessage = {
  id: 'dm-1', other_participant_id: 'user-2', other_participant_display_name: 'Лера',
  created_at: '2026-09-18T10:00:00Z', unread_count: 3,
}

const deletedHistoryItem = {
  id: 'message-2', direct_message_id: 'dm-1', author_id: 'user-2', client_message_id: 'client-2',
  body: '', created_at: '2026-09-18T10:02:00Z', revision: 2, deleted: true,
  reply_to_id: 'message-1', reply_preview: { id: 'message-1', author_id: 'user-1', body: '', deleted: true },
}

describe('direct-message client', () => {
  it('reads the caller-local navigation count through a same-origin GET', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ direct_messages: [directMessage] })))

    await expect(loadDirectMessages(request)).resolves.toMatchObject([{ id: 'dm-1', unreadCount: 3 }])
    expect(request).toHaveBeenCalledWith('/api/v1/direct-messages', expect.objectContaining({ method: 'GET', credentials: 'same-origin' }))
  })

  it('keeps a deleted reply preview empty while loading a paginated DM history', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ messages: [deletedHistoryItem], next_cursor: 'message-1' })))

    await expect(loadDirectMessageHistory('dm-1', undefined, request)).resolves.toMatchObject({ nextCursor: 'message-1', messages: [{ deleted: true, body: '', replyPreview: { deleted: true, body: '' } }] })
    expect(request).toHaveBeenCalledWith('/api/v1/direct-messages/dm-1/messages', expect.objectContaining({ method: 'GET', credentials: 'same-origin' }))
  })

  it('rejects a deleted item that carries hidden text', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ messages: [{ ...deletedHistoryItem, body: 'secret' }] })))

    await expect(loadDirectMessageHistory('dm-1', undefined, request)).rejects.toThrow('некорректную историю')
  })
})
```

- [x] **Step 2: Run the client test to verify it fails**

Run: `npm test -- --run src/direct_message/direct_message_client.spec.ts` from `frontend/`

Expected: FAIL because the client module does not yet exist.

- [x] **Step 3: Implement strict read-only parsing**

```ts
export interface DirectMessageListItem {
  id: string
  otherParticipantId: string
  otherParticipantDisplayName: string
  createdAt: string
  unreadCount: number
}

export interface DirectMessageReplyPreview {
  id: string
  authorId: string
  body: string
  deleted: boolean
}

export interface DirectMessageHistoryItem {
  id: string
  directMessageId: string
  authorId: string
  clientMessageId: string
  body: string
  replyToId?: string
  replyPreview?: DirectMessageReplyPreview
  createdAt: string
  editedAt?: string
  revision: number
  deleted: boolean
}

export interface DirectMessageHistoryPage {
  messages: DirectMessageHistoryItem[]
  nextCursor?: string
}

export type DirectMessageRequest = (input: string, init: RequestInit) => Promise<Response>

function invalidList(): never { throw new Error('Сервер вернул некорректный список личных сообщений.') }
function invalidHistory(): never { throw new Error('Сервер вернул некорректную историю личных сообщений.') }
function record(value: unknown): Record<string, unknown> | null { return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null }
function text(value: unknown): string | null { return typeof value === 'string' ? value : null }
function requiredText(value: unknown): string { const result = text(value); return result ? result : invalidHistory() }
function requiredTextOrEmpty(value: unknown): string { const result = text(value); return result === null ? invalidHistory() : result }
function optionalText(value: unknown): string | undefined { if (value === undefined) return undefined; return text(value) ?? invalidHistory() }
function date(value: unknown): string { const result = requiredText(value); return Number.isNaN(Date.parse(result)) ? invalidHistory() : result }
function optionalDate(value: unknown): string | undefined { if (value === undefined) return undefined; return date(value) }
function count(value: unknown): number { return typeof value === 'number' && Number.isInteger(value) && value >= 0 ? value : invalidList() }
function positive(value: unknown): number { return typeof value === 'number' && Number.isInteger(value) && value > 0 ? value : invalidHistory() }
function boolean(value: unknown): boolean { return typeof value === 'boolean' ? value : invalidHistory() }

async function checked(response: Response): Promise<unknown> {
  if (response.ok) return response.json()
  throw new Error(`Не удалось загрузить личные сообщения (${response.status}).`)
}

function requestInit(): RequestInit { return { method: 'GET', credentials: 'same-origin', headers: { accept: 'application/json' } } }

function directMessage(value: unknown): DirectMessageListItem {
  const source = record(value)
  const id = requiredText(source?.id)
  const otherParticipantId = requiredText(source?.other_participant_id)
  const otherParticipantDisplayName = requiredText(source?.other_participant_display_name)
  const createdAt = date(source?.created_at)
  const unreadCount = count(source?.unread_count)
  return { id, otherParticipantId, otherParticipantDisplayName, createdAt, unreadCount }
}

function replyPreview(value: unknown): DirectMessageReplyPreview | undefined {
  if (value === undefined) return undefined
  const source = record(value)
  const body = requiredTextOrEmpty(source?.body)
  const deleted = boolean(source?.deleted)
  if (!source || (deleted && body !== '')) invalidHistory()
  return { id: requiredText(source.id), authorId: requiredText(source.author_id), body, deleted }
}

function historyItem(value: unknown): DirectMessageHistoryItem {
  const source = record(value)
  const body = requiredTextOrEmpty(source?.body)
  const deleted = boolean(source?.deleted)
  if (!source || (deleted && body !== '')) invalidHistory()
  return {
    id: requiredText(source.id), directMessageId: requiredText(source.direct_message_id), authorId: requiredText(source.author_id),
    clientMessageId: requiredText(source.client_message_id), body, replyToId: optionalText(source.reply_to_id),
    replyPreview: replyPreview(source.reply_preview), createdAt: date(source.created_at), editedAt: optionalDate(source.edited_at),
    revision: positive(source.revision), deleted,
  }
}

export async function loadDirectMessages(request: DirectMessageRequest = fetch): Promise<DirectMessageListItem[]> {
  const source = record(await checked(await request(`${apiBaseUrl}/direct-messages`, requestInit())))
  if (!source || !Array.isArray(source.direct_messages)) invalidList()
  return source.direct_messages.map(directMessage)
}

export async function loadDirectMessageHistory(directMessageId: string, before: string | undefined, request: DirectMessageRequest = fetch): Promise<DirectMessageHistoryPage> {
  const query = before ? `?before=${encodeURIComponent(before)}` : ''
  const source = record(await checked(await request(`${apiBaseUrl}/direct-messages/${encodeURIComponent(directMessageId)}/messages${query}`, requestInit())))
  if (!source || !Array.isArray(source.messages)) invalidHistory()
  return { messages: source.messages.map(historyItem), nextCursor: optionalText(source.next_cursor) }
}
```

The parser must require non-empty string IDs, valid timestamps, a non-negative integer `unread_count`, a positive integer `revision`, and boolean `deleted`.  It must reject a deleted history item or deleted `reply_preview` when its body is not the empty string.  Requests use only `GET`, `credentials: 'same-origin'` and `Accept: application/json`.

- [x] **Step 4: Run the focused client test to verify it passes**

Run: `npm test -- --run src/direct_message/direct_message_client.spec.ts` from `frontend/`

Expected: PASS (three tests).

- [x] **Step 5: Do not stage or commit**

The shared worktree may contain other user changes.  Preserve them and leave the focused files unstaged, as required by the repository `AGENTS.md`.

### Task 2: Pinia selection and history state

**Files:**
- Create: `frontend/src/direct_message/direct_message_store.spec.ts`
- Create: `frontend/src/direct_message/direct_message_store.ts`
- Modify: `docs/superpowers/plans/2026-09-18-direct-message-client-store.md`

- [x] **Step 1: Write failing store tests**

```ts
import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useDirectMessageStore } from './direct_message_store'

describe('direct-message store', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('loads the private navigation list and the selected conversation history', async () => {
    const store = useDirectMessageStore()
    const request = async (input: string) => input.endsWith('/messages')
      ? new Response(JSON.stringify({ messages: [{ id: 'message-1', direct_message_id: 'dm-1', author_id: 'user-2', client_message_id: 'client-1', body: 'Привет', created_at: '2026-09-18T10:00:00Z', revision: 1, deleted: false }] }))
      : new Response(JSON.stringify({ direct_messages: [{ id: 'dm-1', other_participant_id: 'user-2', other_participant_display_name: 'Лера', created_at: '2026-09-18T09:00:00Z', unread_count: 1 }] }))

    await store.refreshNavigation(request)
    await store.open('dm-1', request)

    expect(store.directMessages).toMatchObject([{ id: 'dm-1', unreadCount: 1 }])
    expect(store.directMessageId).toBe('dm-1')
    expect(store.messages).toMatchObject([{ id: 'message-1', body: 'Привет' }])
  })

  it('does not replace the currently selected DM with a delayed history response', async () => {
    const store = useDirectMessageStore()
    let resolveFirst: ((response: Response) => void) | undefined
    const request = (input: string) => input.includes('/dm-a/messages')
      ? new Promise<Response>((resolve) => { resolveFirst = resolve })
      : Promise.resolve(new Response(JSON.stringify({ messages: [{ id: 'message-b', direct_message_id: 'dm-b', author_id: 'user-2', client_message_id: 'client-b', body: 'B', created_at: '2026-09-18T10:00:00Z', revision: 1, deleted: false }] })))

    const firstOpen = store.open('dm-a', request)
    await Promise.resolve()
    await store.open('dm-b', request)
    resolveFirst?.(new Response(JSON.stringify({ messages: [{ id: 'message-a', direct_message_id: 'dm-a', author_id: 'user-1', client_message_id: 'client-a', body: 'A', created_at: '2026-09-18T10:00:00Z', revision: 1, deleted: false }] })))
    await firstOpen

    expect(store.directMessageId).toBe('dm-b')
    expect(store.messages).toMatchObject([{ id: 'message-b' }])
  })
})
```

- [x] **Step 2: Run the store test to verify it fails**

Run: `npm test -- --run src/direct_message/direct_message_store.spec.ts` from `frontend/`

Expected: FAIL because the store module does not yet exist.

- [x] **Step 3: Implement isolated selection state and stale-result protection**

```ts
export const useDirectMessageStore = defineStore('direct-messages', () => {
  const directMessages = ref<DirectMessageListItem[]>([])
  const directMessageId = ref<string | null>(null)
  const messages = ref<DirectMessageHistoryItem[]>([])
  const nextCursor = ref<string | undefined>()
  const loadingNavigation = ref(false)
  const loadingHistory = ref(false)
  const error = ref<string | null>(null)
  let navigationSequence = 0
  let historySequence = 0

  async function refreshNavigation(request?: DirectMessageRequest): Promise<void> {
    const sequence = ++navigationSequence
    loadingNavigation.value = true
    error.value = null
    try {
      const loaded = await loadDirectMessages(request)
      if (sequence === navigationSequence) directMessages.value = loaded
    } catch (cause) {
      if (sequence === navigationSequence) error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить список личных сообщений.'
    } finally {
      if (sequence === navigationSequence) loadingNavigation.value = false
    }
  }

  async function open(nextDirectMessageId: string, request?: DirectMessageRequest): Promise<void> {
    if (directMessageId.value === nextDirectMessageId) return
    directMessageId.value = nextDirectMessageId
    messages.value = []
    nextCursor.value = undefined
    await refreshHistory(request)
  }

  async function refreshHistory(request?: DirectMessageRequest): Promise<void> {
    const targetDirectMessageId = directMessageId.value
    if (!targetDirectMessageId) return
    const sequence = ++historySequence
    loadingHistory.value = true
    error.value = null
    try {
      const page = await loadDirectMessageHistory(targetDirectMessageId, undefined, request)
      if (directMessageId.value !== targetDirectMessageId || sequence !== historySequence) return
      messages.value = page.messages
      nextCursor.value = page.nextCursor
    } catch (cause) {
      if (directMessageId.value === targetDirectMessageId && sequence === historySequence) error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить историю личных сообщений.'
    } finally {
      if (sequence === historySequence) loadingHistory.value = false
    }
  }

  return { directMessageId, directMessages, error, loadingHistory, loadingNavigation, messages, nextCursor, open, refreshHistory, refreshNavigation }
})
```

`refreshHistory` must read the selected ID once, increment `historySequence`, and apply results/errors/loading changes only if both the ID and sequence still match.  Neither the store nor the client calls `PUT /read-cursor`; the later DM panel must explicitly gate that mutation on selected and visible state.

- [x] **Step 4: Run the focused store test to verify it passes**

Run: `npm test -- --run src/direct_message/direct_message_store.spec.ts` from `frontend/`

Expected: PASS (two tests).

- [x] **Step 5: Mark completed plan tasks after passing checks**

Replace the completed task checkboxes in this plan with `[x]`, retaining the commands and expected outcomes as execution evidence.

### Task 3: Regression validation

**Files:**
- Modify: `docs/superpowers/plans/2026-09-18-direct-message-client-store.md`

- [x] **Step 1: Run the complete frontend test suite**

Run: `npm test -- --run`

Expected: PASS; no existing text-chat, topology or voice frontend tests regress.

- [x] **Step 2: Type-check and build the browser bundle**

Run: `npm run build`

Expected: PASS; `vue-tsc --noEmit` and Vite production build succeed.

- [x] **Step 3: Re-run traceability and inspect the patch**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1`

Expected: PASS; REQ-DM-01 and REQ-CHAT-02 retain their trace links.

Run: `git diff --check`

Expected: exit 0; no newly introduced whitespace errors.

- [x] **Step 4: Record the verification boundary**

Record in the final handoff that these are mocked HTTP/client-state tests only.  The packet does not provide browser visibility evidence, real PostgreSQL ACL evidence, media evidence, desktop notifications, or a user-visible DM navigation.
