# Direct Message Candidate Selector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an authenticated user select an active in-guild participant, open the server-authoritative canonical 1:1 DM pair, and enter it without exposing account metadata outside the product contract.

**Architecture:** Add a focused HTTP client for the candidate list and existing-pair/open-pair response, plus a Pinia store that owns paging, opening state and the `NOT_FOUND` race message. A compact sidebar dialog consumes that store and emits only the resulting DM ID; `App.vue` refreshes its existing DM navigation then selects the returned pair.

**Tech Stack:** Vue 3, TypeScript, Pinia, Vite, Vitest, existing Go API contract.

---

### Task 1: Candidate/open HTTP boundary

**Files:**
- Create: `frontend/src/direct_message/direct_message_candidate_client.ts`
- Test: `frontend/src/direct_message/direct_message_candidate_client.spec.ts`

- [x] **Step 1: Write failing client tests for cursor loading, pair opening, and the unavailable-target response.**

```ts
await expect(loadDirectMessageCandidates(undefined, request)).resolves.toMatchObject({
  candidates: [{ id: 'user-2', displayName: 'Лера' }], nextAfter: 'user-2',
})
await expect(openDirectMessage('user-2', request)).resolves.toMatchObject({ id: 'dm-1' })
await expect(openDirectMessage('user-2', notFoundRequest)).rejects.toMatchObject({ status: 404, code: 'NOT_FOUND' })
```

- [x] **Step 2: Run the focused test to verify that its imports cannot resolve.**

Run: `npm test -- --run src/direct_message/direct_message_candidate_client.spec.ts`

Expected: FAIL because `direct_message_candidate_client` does not exist.

- [x] **Step 3: Implement a separate typed client.**

```ts
export interface DirectMessageCandidate { id: string; displayName: string }
export interface DirectMessageCandidatePage { candidates: DirectMessageCandidate[]; nextAfter?: string }
export class DirectMessageCandidateRequestError extends Error {
  constructor(readonly status: number, readonly code?: string) { super(`Запрос к личным сообщениям отклонён (${status}).`) }
}
export async function loadDirectMessageCandidates(after?: string, request: DirectMessageRequest = fetch): Promise<DirectMessageCandidatePage>
export async function openDirectMessage(participantId: string, request: DirectMessageRequest = fetch): Promise<OpenedDirectMessage>
```

Use only `/api/v1/direct-message-candidates` and `POST /api/v1/direct-messages`, `credentials: 'same-origin'`, JSON request/response bodies, URL encoding for the cursor, and strict runtime checks for identifiers, display names and ISO dates. Parse the API error envelope only to preserve its status and code; never surface or log response data.

- [x] **Step 4: Run the focused client test.**

Run: `npm test -- --run src/direct_message/direct_message_candidate_client.spec.ts`

Expected: PASS with request URLs, JSON body, `NOT_FOUND`, and response mappings asserted.

### Task 2: Candidate selection state

**Files:**
- Create: `frontend/src/direct_message/direct_message_candidate_store.ts`
- Test: `frontend/src/direct_message/direct_message_candidate_store.spec.ts`

- [x] **Step 1: Write failing store tests for page merge, next cursor, successful open, and a target that disappeared after listing.**

```ts
await store.refresh(request)
await store.loadNext(request)
expect(store.candidates.map((candidate) => candidate.id)).toEqual(['user-2', 'user-3'])
await expect(store.open('user-2', request)).resolves.toBe('dm-1')
await expect(store.open('user-2', notFoundRequest)).resolves.toBeNull()
expect(store.error).toBe('Участник больше недоступен. Обновите список.')
```

- [x] **Step 2: Run the focused test to verify that its store import cannot resolve.**

Run: `npm test -- --run src/direct_message/direct_message_candidate_store.spec.ts`

Expected: FAIL because `direct_message_candidate_store` does not exist.

- [x] **Step 3: Implement a store with bounded local state.**

```ts
const candidates = ref<DirectMessageCandidate[]>([])
const nextAfter = ref<string | undefined>()
const loading = ref(false)
const opening = ref(false)
const error = ref<string | null>(null)
async function refresh(request?: DirectMessageRequest): Promise<void>
async function loadNext(request?: DirectMessageRequest): Promise<void>
async function open(participantId: string, request?: DirectMessageRequest): Promise<string | null>
```

`refresh` replaces the page, `loadNext` appends only new IDs from its cursor, and request sequence counters prevent late pages replacing newer state. `open` serializes the action while `opening` is true and maps HTTP `404` with code `NOT_FOUND` to the specified Russian recovery message; other failures retain a neutral request error. Return only the opened DM ID on success.

- [x] **Step 4: Run the focused store test.**

Run: `npm test -- --run src/direct_message/direct_message_candidate_store.spec.ts`

Expected: PASS with cursor merge, returned DM ID, and unavailable-target UX asserted.

### Task 3: Sidebar dialog and navigation handoff

**Files:**
- Create: `frontend/src/direct_message/DirectMessageStarter.vue`
- Modify: `frontend/src/direct_message/DirectMessageNavigation.vue`
- Modify: `frontend/src/App.vue`

- [x] **Step 1: Add a starter component with a deliberate trigger and complete UI states.**

```vue
<button class="channel-button" type="button" @click="show">Начать диалог</button>
<section v-if="visible" role="dialog" aria-modal="true" aria-labelledby="direct-message-starter-title">
  <h3 id="direct-message-starter-title">Новый личный диалог</h3>
  <p v-if="store.loading" aria-live="polite">Загружаем участников…</p>
  <p v-else-if="store.error" role="alert">{{ store.error }}</p>
  <button v-for="candidate in store.candidates" :key="candidate.id" type="button" :disabled="store.opening" @click="choose(candidate.id)">{{ candidate.displayName }}</button>
</section>
```

Call `store.refresh()` only when opening the dialog, expose a close button, a no-candidate state, and a disabled `Загрузить ещё` button while an additional page is pending. On a successful selection, close the dialog and emit `open` with the returned DM ID. Do not render a login, role, blocked flag, profile data or API error body.

- [x] **Step 2: Relay the starter's `open` event through `DirectMessageNavigation.vue`.**

```ts
const emit = defineEmits<{ select: [directMessageId: string]; open: [directMessageId: string] }>()
```

Mount `<DirectMessageStarter @open="emit('open', $event)" />` beneath the private-message heading, preserving the selected/unread list behavior.

- [x] **Step 3: Refresh the existing navigation and select the returned pair in `App.vue`.**

```ts
async function selectOpenedDirectMessage(directMessageId: string): Promise<void> {
  await directMessageStore.refreshNavigation()
  selectDirectMessage(directMessageId)
}
```

Bind `@open="selectOpenedDirectMessage"` on `DirectMessageNavigation`. This preserves independent voice state because the established `selectDirectMessage` workspace transition remains the only selection path.

- [x] **Step 4: Build the frontend.**

Run: `npm run build`

Expected: PASS after Vue template/type checking and Vite production build.

### Task 4: Packet validation and review

**Files:**
- Modify: `docs/superpowers/plans/2026-09-18-direct-message-candidate-selector.md`

- [x] **Step 1: Run the frontend suite.**

Run: `npm test -- --run`

Expected: PASS; prior DM navigation, history, read-cursor, composer, and new selector behavior remain green.

- [x] **Step 2: Run unchanged-spec traceability and diff integrity checks.**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1`

Run: `git diff --check`

Expected: both commands exit `0`; no production contract changed, so the contract verifier is not required for this client-only packet.

- [x] **Step 3: Inspect scope before handoff.**

Run: `git status --short`

Run: `Get-ChildItem frontend/src/direct_message/direct_message_candidate_client.ts,frontend/src/direct_message/direct_message_candidate_store.ts,frontend/src/direct_message/DirectMessageStarter.vue | Select-Object Name,Length`

Expected: only this leaf's files are assessed; do not stage or commit the shared dirty worktree.

## Self-review

- REQ-DM-01 is covered by Tasks 1–3: participant selection uses the restricted candidate endpoint and pair creation remains server-authoritative.
- The race between listing and opening is covered by Task 2's `NOT_FOUND` test and Task 3's alert state.
- The DM API contract is unchanged; Task 4 therefore runs traceability and frontend checks rather than asserting a new server contract.
- Identifiers, type names, function signatures, cursor name, event name, and Russian unavailable-target message are consistent across all tasks.
- No deferred work or vague failure-handling instruction remains in this plan.
