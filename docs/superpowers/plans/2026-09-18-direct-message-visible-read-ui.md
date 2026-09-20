# Direct-message visible-read UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the authenticated caller's direct-message navigation and selected history, and advance a DM cursor only after that history is selected and displayed in a visible browser document.

**Architecture:** The API client owns the existing `PUT /read-cursor` request and response shape.  A small pure gate accepts the selected DM ID, rendered DM ID, newest displayed message ID and document visibility state; it is testable without a browser and is the sole route to the mutation.  The Vue component calls that gate after DOM updates and on `visibilitychange`; its surrounding Pinia/navigation state clears the channel surface whenever a DM is selected.

**Tech Stack:** Vue 3, TypeScript, Pinia, Vite, Vitest.

---

### Task 1: Read-cursor client and visibility gate

**Files:**
- Modify: `frontend/src/direct_message/direct_message_client.ts`
- Modify: `frontend/src/direct_message/direct_message_client.spec.ts`
- Create: `frontend/src/direct_message/direct_message_read_gate.ts`
- Create: `frontend/src/direct_message/direct_message_read_gate.spec.ts`

- [x] **Step 1: Write failing cursor-client and gate tests**

```ts
it('advances one caller cursor through the guarded same-origin endpoint', async () => {
  const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
    direct_message_id: 'dm-1', message_id: 'message-2', message_created_at: '2026-09-18T10:02:00Z',
  })))

  await expect(advanceDirectMessageReadCursor('dm-1', 'message-2', request)).resolves.toMatchObject({ directMessageId: 'dm-1', messageId: 'message-2' })
  expect(request).toHaveBeenCalledWith('/api/v1/direct-messages/dm-1/read-cursor', expect.objectContaining({ method: 'PUT', credentials: 'same-origin', body: '{"message_id":"message-2"}' }))
})

it('does not call the mutation for a hidden, unselected or empty conversation', async () => {
  const advance = vi.fn()
  await expect(advanceReadIfVisible({ activeDirectMessageId: 'dm-1', renderedDirectMessageId: 'dm-1', newestDisplayedMessageId: 'message-2', visibilityState: 'hidden' }, advance)).resolves.toBe(false)
  await expect(advanceReadIfVisible({ activeDirectMessageId: 'dm-2', renderedDirectMessageId: 'dm-1', newestDisplayedMessageId: 'message-2', visibilityState: 'visible' }, advance)).resolves.toBe(false)
  await expect(advanceReadIfVisible({ activeDirectMessageId: 'dm-1', renderedDirectMessageId: 'dm-1', newestDisplayedMessageId: undefined, visibilityState: 'visible' }, advance)).resolves.toBe(false)
  expect(advance).not.toHaveBeenCalled()
})

it('uses the newest displayed message only for an active visible DM', async () => {
  const advance = vi.fn().mockResolvedValue(undefined)
  await expect(advanceReadIfVisible({ activeDirectMessageId: 'dm-1', renderedDirectMessageId: 'dm-1', newestDisplayedMessageId: 'message-2', visibilityState: 'visible' }, advance)).resolves.toBe(true)
  expect(advance).toHaveBeenCalledWith('dm-1', 'message-2')
})
```

- [x] **Step 2: Run the focused tests to verify they fail**

Run: `npm test -- --run src/direct_message/direct_message_client.spec.ts src/direct_message/direct_message_read_gate.spec.ts` from `frontend/`

Expected: FAIL because the cursor function and visibility-gate module do not exist.

- [x] **Step 3: Implement the typed mutation and explicit gate**

```ts
export interface DirectMessageReadCursor {
  directMessageId: string
  messageId: string
  messageCreatedAt: string
}

export async function advanceDirectMessageReadCursor(directMessageId: string, messageId: string, request: DirectMessageRequest = fetch): Promise<DirectMessageReadCursor> {
  if (!directMessageId || !messageId) invalidHistory()
  const response = await request(`${apiBaseUrl}/direct-messages/${encodeURIComponent(directMessageId)}/read-cursor`, requestInit('PUT', { message_id: messageId }))
  return readCursor(await checked(response))
}

export interface ReadGateInput {
  activeDirectMessageId: string | null
  renderedDirectMessageId: string | null
  newestDisplayedMessageId?: string
  visibilityState: string
}

export type ReadCursorAdvancer = (directMessageId: string, messageId: string) => Promise<unknown>

export async function advanceReadIfVisible(input: ReadGateInput, advance: ReadCursorAdvancer = advanceDirectMessageReadCursor): Promise<boolean> {
  if (input.visibilityState !== 'visible' || input.activeDirectMessageId !== input.renderedDirectMessageId || !input.renderedDirectMessageId || !input.newestDisplayedMessageId) return false
  await advance(input.renderedDirectMessageId, input.newestDisplayedMessageId)
  return true
}
```

`requestInit` must preserve `credentials: 'same-origin'` and add JSON `content-type` only for the `PUT` body.  `readCursor` must require non-empty IDs and a valid `message_created_at` timestamp.  The gate receives a `ReadCursorAdvancer` dependency so its tests do not create HTTP traffic.

- [x] **Step 4: Run the focused tests to verify they pass**

Run: `npm test -- --run src/direct_message/direct_message_client.spec.ts src/direct_message/direct_message_read_gate.spec.ts` from `frontend/`

Expected: PASS; hidden, mismatched and empty states perform no mutation.

- [x] **Step 5: Do not stage or commit**

Keep the focused files unstaged because the shared worktree can contain unrelated user changes.

### Task 2: Mutually exclusive DM navigation state

**Files:**
- Modify: `frontend/src/direct_message/direct_message_store.ts`
- Modify: `frontend/src/direct_message/direct_message_store.spec.ts`
- Modify: `frontend/src/voice/navigation_store.ts`
- Modify: `frontend/src/voice/navigation_store.spec.ts`
- Modify: `frontend/src/workspace/voice_controls.ts`

- [x] **Step 1: Write failing state tests**

```ts
it('clears a selected DM and invalidates an outstanding history request', async () => {
  const store = useDirectMessageStore()
  let resolveHistory: ((response: Response) => void) | undefined
  const opening = store.open('dm-1', () => new Promise<Response>((resolve) => { resolveHistory = resolve }))
  await Promise.resolve()
  store.close()
  resolveHistory?.(new Response(JSON.stringify({ messages: [] })))
  await opening

  expect(store.directMessageId).toBeNull()
  expect(store.messages).toEqual([])
})

it('uses DM as the selected surface without changing an active voice connection', () => {
  const store = useVoiceNavigationStore()
  store.confirmVoiceConnected('voice-1')
  store.selectDirectMessage('dm-1')

  expect(store.selectedSurface).toEqual({ kind: 'DM', directMessageId: 'dm-1' })
  expect(store.activeVoiceChannelId).toBe('voice-1')
})
```

- [x] **Step 2: Run the focused state tests to verify they fail**

Run: `npm test -- --run src/direct_message/direct_message_store.spec.ts src/voice/navigation_store.spec.ts` from `frontend/`

Expected: FAIL because `close` and `selectDirectMessage` do not exist.

- [x] **Step 3: Implement selected-surface transitions**

```ts
export type SelectedSurface =
  | { kind: 'NONE' }
  | { kind: 'TEXT' | 'VOICE'; channelId: string }
  | { kind: 'DM'; directMessageId: string }

function selectDirectMessage(directMessageId: string): void {
  selectedSurface.value = { kind: 'DM', directMessageId }
}

function close(): void {
  historySequence++
  directMessageId.value = null
  messages.value = []
  nextCursor.value = undefined
  loadingHistory.value = false
  error.value = null
}
```

`selectedChannelId` in `useWorkspaceVoiceControls` must return a channel ID only for `TEXT` or `VOICE`, and the exported `selectDirectMessage` wrapper must delegate to the navigation store.  This preserves a live voice connection while switching the central surface to a DM.

- [x] **Step 4: Run the focused state tests to verify they pass**

Run: `npm test -- --run src/direct_message/direct_message_store.spec.ts src/voice/navigation_store.spec.ts` from `frontend/`

Expected: PASS; stale history cannot fill a closed DM and a selected DM clears the channel selection.

### Task 3: Accessible DM navigation and history surface

**Files:**
- Create: `frontend/src/direct_message/DirectMessageNavigation.vue`
- Create: `frontend/src/direct_message/DirectMessageConversation.vue`
- Modify: `frontend/src/App.vue`
- Modify: `frontend/src/conversation/ConversationPane.vue`

- [x] **Step 1: Add the DM list and selected-history components**

```vue
<button
  v-for="directMessage in props.directMessages"
  :key="directMessage.id"
  class="channel-button"
  :class="{ selected: props.selectedDirectMessageId === directMessage.id }"
  :aria-current="props.selectedDirectMessageId === directMessage.id ? 'page' : undefined"
  type="button"
  @click="emit('select', directMessage.id)"
>
  <span>{{ directMessage.otherParticipantDisplayName }}</span>
  <span v-if="directMessage.unreadCount" class="channel-state">{{ directMessage.unreadCount }}</span>
</button>
```

```ts
watch([() => props.directMessageId, () => store.directMessageId, () => store.messages], queueVisibleRead, { flush: 'post' })
onMounted(() => {
  document.addEventListener('visibilitychange', queueVisibleRead)
  queueVisibleRead()
})
onBeforeUnmount(() => document.removeEventListener('visibilitychange', queueVisibleRead))

async function markVisibleRead(): Promise<void> {
  try {
    if (await advanceReadIfVisible({ activeDirectMessageId: store.directMessageId, renderedDirectMessageId: props.directMessageId, newestDisplayedMessageId: store.messages.at(0)?.id, visibilityState: document.visibilityState })) void store.refreshNavigation()
  } catch { return }
}
function queueVisibleRead(): void { void markVisibleRead() }
```

The history template must have Russian loading, error and empty states, use `MessageBody` for non-deleted message content, and render a deleted reply preview as `Сообщение удалено`.  The `watch` uses `flush: 'post'`, so the client advances only after Vue has rendered the selected history.

- [x] **Step 2: Wire the central surface and sidebar**

```ts
const selectedDirectMessage = computed(() => directMessageStore.directMessages.find((item) => item.id === directMessageStore.directMessageId) ?? null)

function selectChannel(channel: TopologyChannel): void {
  directMessageStore.close()
  selectWorkspaceChannel(channel)
}

function selectDirectMessage(directMessageId: string): void {
  selectWorkspaceDirectMessage(directMessageId)
  void directMessageStore.open(directMessageId)
}
```

`App.vue` refreshes the DM list on mount and during realtime resync, and passes the selected item to `ConversationPane`.  `ConversationPane` renders `DirectMessageConversation` before its channel branches when that selected item is present.  Its `ChannelNavigation` receives no selected channel when a DM is selected because `selectedChannelId` is `null`.

- [x] **Step 3: Type-check and build the integrated surface**

Run: `npm run build` from `frontend/`

Expected: PASS; TypeScript accepts the updated selected-surface union and Vite compiles both Vue components.

### Task 4: Regression validation and closeout

**Files:**
- Modify: `docs/superpowers/plans/2026-09-18-direct-message-visible-read-ui.md`

- [x] **Step 1: Run all frontend tests**

Run: `npm test -- --run` from `frontend/`

Expected: PASS; direct-message, text-chat, navigation and voice tests all remain green.

- [x] **Step 2: Verify requirement traceability and whitespace**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1`

Expected: PASS; all requirements remain linked.

Run: `git diff --check`

Expected: exit 0 with no new whitespace error.

- [x] **Step 3: Mark completed plan tasks and state the verification boundary**

Replace completed checkboxes with `[x]`.  Record that frontend tests prove client gating and state transitions only; real two-account ACL, browser rendering, Windows/macOS media POC, load, deployment and release gates still require their dedicated evidence.
