# Direct-message composer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an authenticated DM participant send, reply to, edit and delete only their own messages through the existing protected API.

**Architecture:** A dedicated mutation client maps the POST/PATCH/DELETE contracts into the existing history-item shape and preserves same-origin cookies plus server error responses. A focused action factory operates only on the currently selected store state and rejects stale completions. The history component uses the shared safe message renderer and enables controls only for the current account's own messages; administrators receive no DM moderation control.

**Tech Stack:** Vue 3, TypeScript, Pinia, Vite, Vitest.

---

### Task 1: Direct-message mutation protocol

**Files:**
- Create: `frontend/src/direct_message/direct_message_mutation_client.ts`
- Create: `frontend/src/direct_message/direct_message_mutation_client.spec.ts`

- [x] **Step 1: Write failing mutation-client tests**

```ts
it('uses idempotent send, guarded edit and author-delete endpoints', async () => {
  const request = vi.fn()
    .mockResolvedValueOnce(new Response(JSON.stringify({ id: 'message-1', direct_message_id: 'dm-1', author_id: 'user-1', client_message_id: 'client-1', body: 'Привет', revision: 1, created_at: '2026-09-18T10:00:00Z' })))
    .mockResolvedValueOnce(new Response(JSON.stringify({ id: 'message-1', direct_message_id: 'dm-1', author_id: 'user-1', client_message_id: 'client-1', body: 'Исправлено', revision: 2, created_at: '2026-09-18T10:00:00Z', edited_at: '2026-09-18T10:01:00Z' })))
    .mockResolvedValueOnce(new Response(null, { status: 204 }))
  await expect(createDirectMessage('dm-1', 'client-1', 'Привет', request, 'message-0')).resolves.toMatchObject({ deleted: false, replyToId: 'message-0' })
  await expect(editDirectMessage('dm-1', 'message-1', 'Исправлено', 1, request)).resolves.toMatchObject({ revision: 2, editedAt: '2026-09-18T10:01:00Z' })
  await expect(deleteDirectMessage('dm-1', 'message-1', request)).resolves.toBeUndefined()
  expect(request).toHaveBeenNthCalledWith(1, '/api/v1/direct-messages/dm-1/messages', expect.objectContaining({ method: 'POST', body: '{"client_message_id":"client-1","body":"Привет","reply_to_id":"message-0"}' }))
  expect(request).toHaveBeenNthCalledWith(2, '/api/v1/direct-messages/dm-1/messages/message-1', expect.objectContaining({ method: 'PATCH', body: '{"body":"Исправлено","expected_revision":1}' }))
  expect(request).toHaveBeenNthCalledWith(3, '/api/v1/direct-messages/dm-1/messages/message-1', expect.objectContaining({ method: 'DELETE' }))
})
```

- [x] **Step 2: Run the focused client test to verify it fails**

Run: `npm test -- --run src/direct_message/direct_message_mutation_client.spec.ts` from `frontend/`

Expected: FAIL because the mutation client module does not exist.

- [x] **Step 3: Implement contract-shaped same-origin mutations**

```ts
export async function createDirectMessage(directMessageId: string, clientMessageId: string, body: string, request: DirectMessageRequest = fetch, replyToId?: string): Promise<DirectMessageHistoryItem> {
  return message(await checked(await request(`${apiBaseUrl}/direct-messages/${encodeURIComponent(directMessageId)}/messages`, requestInit('POST', { client_message_id: clientMessageId, body, ...(replyToId ? { reply_to_id: replyToId } : {}) }))))
}
export async function editDirectMessage(directMessageId: string, messageId: string, body: string, expectedRevision: number, request: DirectMessageRequest = fetch): Promise<DirectMessageHistoryItem> {
  return message(await checked(await request(`${apiBaseUrl}/direct-messages/${encodeURIComponent(directMessageId)}/messages/${encodeURIComponent(messageId)}`, requestInit('PATCH', { body, expected_revision: expectedRevision }))))
}
export async function deleteDirectMessage(directMessageId: string, messageId: string, request: DirectMessageRequest = fetch): Promise<void> {
  await checked(await request(`${apiBaseUrl}/direct-messages/${encodeURIComponent(directMessageId)}/messages/${encodeURIComponent(messageId)}`, requestInit('DELETE')))
}
```

The mapper requires non-empty IDs and bodies, a positive revision and valid timestamps. It sets `deleted: false` only for successful POST/PATCH responses. `requestInit` uses same-origin credentials and JSON only where a body exists; server-side authorisation remains authoritative.

- [x] **Step 4: Run the focused client test to verify it passes**

Run: `npm test -- --run src/direct_message/direct_message_mutation_client.spec.ts` from `frontend/`

Expected: PASS; all three calls retain same-origin credentials and exact JSON fields.

- [x] **Step 5: Keep the shared tree unstaged**

Do not stage or commit shared worktree changes.

### Task 2: Selected-DM message action state

**Files:**
- Create: `frontend/src/direct_message/direct_message_message_actions.ts`
- Modify: `frontend/src/direct_message/direct_message_store.ts`
- Modify: `frontend/src/direct_message/direct_message_store.spec.ts`

- [x] **Step 1: Write failing store action tests**

```ts
it('prepends a server-created message only to the still-selected DM', async () => {
  const store = useDirectMessageStore()
  const request = async (_input: string, init: RequestInit) => init.method === 'GET'
    ? new Response(JSON.stringify({ messages: [] }))
    : new Response(JSON.stringify({ id: 'message-1', direct_message_id: 'dm-1', author_id: 'user-1', client_message_id: 'client-1', body: 'Привет', revision: 1, created_at: '2026-09-18T10:00:00Z' }))
  await store.open('dm-1', request)
  await expect(store.send('Привет', request, () => 'client-1', 'message-0')).resolves.toBe(true)
  expect(store.messages).toMatchObject([{ id: 'message-1', replyToId: 'message-0', deleted: false }])
})

it('immediately masks only the selected message after an author-delete', async () => {
  const store = useDirectMessageStore()
  const request = async (_input: string, init: RequestInit) => init.method === 'GET'
    ? new Response(JSON.stringify({ messages: [{ id: 'message-1', direct_message_id: 'dm-1', author_id: 'user-1', client_message_id: 'client-1', body: 'Привет', revision: 1, created_at: '2026-09-18T10:00:00Z', deleted: false }] }))
    : new Response(null, { status: 204 })
  await store.open('dm-1', request)
  await expect(store.remove('message-1', request)).resolves.toBe(true)
  expect(store.messages).toMatchObject([{ body: '', deleted: true, revision: 2 }])
})
```

- [x] **Step 2: Run the focused store test to verify it fails**

Run: `npm test -- --run src/direct_message/direct_message_store.spec.ts` from `frontend/`

Expected: FAIL because the store does not expose `send` or `remove`.

- [x] **Step 3: Implement mutation actions with selected-ID checks**

```ts
async function send(body: string, request?: DirectMessageRequest, createId: () => string = () => crypto.randomUUID(), replyToId?: string): Promise<boolean> {
  const targetDirectMessageId = state.directMessageId.value
  if (!targetDirectMessageId || state.sending.value || !body) return false
  state.sending.value = true
  try {
    const created = await createDirectMessage(targetDirectMessageId, createId(), body, request, replyToId)
    if (state.directMessageId.value !== targetDirectMessageId) return false
    state.messages.value = [created, ...state.messages.value.filter((message) => message.id !== created.id)]
    return true
  } catch (cause) {
    if (state.directMessageId.value === targetDirectMessageId) state.error.value = cause instanceof Error ? cause.message : 'Не удалось отправить личное сообщение.'
    return false
  } finally {
    state.sending.value = false
  }
}
```

The action factory also replaces an edited server response by ID and masks an acknowledged deletion with `{ body: '', deleted: true, revision: message.revision + 1 }`. The store passes selected ID, messages, `sending` ref and error ref to the factory, then exposes `send`, `edit` and `remove` while its read state remains focused.

- [x] **Step 4: Run the focused store test to verify it passes**

Run: `npm test -- --run src/direct_message/direct_message_store.spec.ts` from `frontend/`

Expected: PASS; selected-DM mutation results cannot appear in a different DM.

### Task 3: Author-only DM composer UI

**Files:**
- Modify: `frontend/src/direct_message/DirectMessageConversation.vue`

- [x] **Step 1: Add session-aware message controls and composer**

```vue
<MessageItem :message="message" :reply-preview="replyPreview(message)" :can-edit="session?.accountId === message.authorId" :can-delete="session?.accountId === message.authorId" @edit="edit(message, $event)" @remove="remove(message)" @reply="replyTarget = message" />
<form class="message-composer" @submit.prevent="send">
  <p v-if="replyTarget" class="reply-target">Ответ для {{ replyTarget.authorId }} <button type="button" @click="replyTarget = null">Отмена</button></p>
  <label for="direct-message-body">Сообщение</label>
  <textarea id="direct-message-body" v-model="draft" maxlength="8000" :disabled="store.sending" placeholder="Введите текст или emoji" />
  <button class="voice-join" type="submit" :disabled="store.sending || !draft">{{ store.sending ? 'Отправляем…' : 'Отправить' }}</button>
</form>
```

Load the current session on mount. `send` preserves the draft and reply target after a rejected API request and clears both only on a `true` store result. No administrator condition appears in edit/delete props.

- [x] **Step 2: Type-check and build the integrated composer**

Run: `npm run build` from `frontend/`

Expected: PASS; `DirectMessageHistoryItem` remains structurally compatible with the shared safe `MessageItem` renderer.

### Task 4: Regression validation and closeout

**Files:**
- Modify: `docs/superpowers/plans/2026-09-18-direct-message-composer.md`

- [x] **Step 1: Run all frontend tests**

Run: `npm test -- --run` from `frontend/`

Expected: PASS; no text-chat, DM navigation or voice behaviour regresses.

- [x] **Step 2: Verify traceability and whitespace**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1`

Expected: PASS; REQ-DM-01 and REQ-SECURITY-02 stay linked.

Run: `git diff --check`

Expected: exit 0 with no newly introduced whitespace errors.

- [x] **Step 3: Mark completed checklist items and record scope**

Replace completed boxes with `[x]`. Report that frontend tests check protocol and selected-state behaviour only; live two-party ACL, search, attachment, notifications, Windows/macOS POC, capacity, deployment and release evidence remain separate gates.
