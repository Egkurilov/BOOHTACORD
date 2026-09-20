# Text Channel Search UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an authenticated user search non-deleted text messages in the currently open text channel through the deployed, server-authorized search endpoint.

**Architecture:** A small typed client owns response parsing and same-origin GET requests. `TextMessageSearch.vue` owns query, cursor page, loading, error and channel-reset state; `TextConversation.vue` mounts it for the selected text channel. Search results render through the existing safe `MessageBody` renderer, while the API remains the only ACL authority.

**Tech Stack:** Vue 3 Composition API, TypeScript, Vite, Vitest, existing Go/OpenAPI search endpoint.

---

### Task 1: Add and pin the typed search client

**Files:**
- Create: `frontend/src/conversation/text_message_search_client.spec.ts`
- Create: `frontend/src/conversation/text_message_search_client.ts`

- [x] **Step 1: Write client regression tests first.**

Test a response page containing one message, then assert:

```ts
expect(request).toHaveBeenCalledWith(
  '/api/v1/channels/text-1/search?query=%22%D0%B8%D0%B3%D1%80%D0%B0%22&before=message-2&limit=20',
  expect.objectContaining({ method: 'GET', credentials: 'same-origin' }),
)
```

Add a malformed response test where `revision: 0` rejects with `некорректные результаты` rather than rendering untrusted data.

- [x] **Step 2: Run the focused test before implementation.**

Run: `npm test -- src/conversation/text_message_search_client.spec.ts`

Expected: FAIL because the client module does not exist.

- [x] **Step 3: Implement the bounded client.**

Define:

```ts
export interface TextMessageSearchResult {
  id: string; channelId: string; authorId: string; body: string
  createdAt: string; editedAt?: string; revision: number
}
export interface TextMessageSearchPage { messages: TextMessageSearchResult[]; nextCursor?: string }
export async function searchTextMessages(channelId: string, query: string, before?: string, limit = 50, request: MessageRequest = fetch): Promise<TextMessageSearchPage>
```

URL-encode path/query/cursor; require an object with an array `messages`, a valid date, positive integer revision and string fields. Reuse `MessageRequestError` for non-OK results; do not log queries or message bodies.

- [x] **Step 4: Re-run the focused test.**

Expected: PASS.

### Task 2: Render a channel-scoped accessible search surface

**Files:**
- Create: `frontend/src/conversation/TextMessageSearch.vue`
- Modify: `frontend/src/conversation/TextConversation.vue`
- Modify: `frontend/src/style.css`

- [x] **Step 1: Implement the search component with channel-reset protection.**

Accept `channelId` and use a monotonically increasing request sequence. A watcher clears `messages`, `nextCursor`, error and status whenever the channel changes; results from a prior channel must be ignored. Trim only for the empty-query guard; submit the original query to the client so server semantics remain authoritative.

Use a form with `role="search"`, a labelled query input (`maxlength="256"`), a disabled state while loading, an alert for errors, a polite status for zero/page results, and a `Показать ещё` button only when `nextCursor` exists. Render each `body` through `MessageBody`, never `v-html`.

- [x] **Step 2: Mount search above the existing message history.**

Add the exact import and element:

```vue
<TextMessageSearch :channel-id="props.channelId" />
```

The existing history, compose, edit, delete and reply behavior must remain unchanged.

- [x] **Step 3: Add local visual styles.**

Use `.text-message-search`, `.text-search-form`, `.text-search-results`, `.text-search-result`, `.text-search-status`, and `.text-search-error`. Match existing dark controls and preserve visible focus; do not add a global selector or alter voice/screen styles.

### Task 3: Validate and release the web leaf

**Files:**
- Modify: `docs/superpowers/plans/2026-09-18-text-channel-search-ui.md`

- [x] **Step 1: Run frontend, contract and traceability checks.**

Run:

```powershell
Push-Location frontend
npm test
npm run build
Pop-Location
scripts/verify-contracts.ps1
scripts/verify-spec-traceability.ps1
git diff --check
```

Expected: all checks pass.

- [x] **Step 2: Inspect scoped files without staging.**

Run `git status --short` and inspect file sizes. Keep the dirty worktree intact; do not stage or commit unrelated work.

- [x] **Step 3: Release only the frontend image and smoke public guest boundaries.**

Build one uniquely tagged non-`latest` web image from the validated frontend inputs, update only `WEB_IMAGE`, recreate only `web`, and confirm HTTPS landing/health/session are `200`. Do not authenticate, create channels, enter a search query, or claim browser/real-PostgreSQL search acceptance.

**Coverage review:** This leaf completes the text-channel search client surface within T-043. It does not add DM search UI, cross-channel/global search, attachment search, optimistic/realtime search updates, owner login, real PostgreSQL data assertions, or POC evidence.
