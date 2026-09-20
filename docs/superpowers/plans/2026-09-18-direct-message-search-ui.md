# Direct Message Search UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a participant search non-deleted messages only in the currently opened direct-message pair through the existing participant-authorized server endpoint.

**Architecture:** A typed `direct_message_search_client` owns response validation and credentialed HTTP. `DirectMessageSearch.vue` owns local query, cursor, pending/error state and resets/invalidation when its `directMessageId` changes. The existing API checks canonical-pair membership; the browser neither supplies a role nor treats an ID as access proof.

**Tech Stack:** Vue 3 Composition API, TypeScript, Vitest, deployed Go direct-message search API.

---

### Task 1: Pin the private search HTTP client

**Files:**
- Create: `frontend/src/direct_message/direct_message_search_client.spec.ts`
- Create: `frontend/src/direct_message/direct_message_search_client.ts`

- [x] **Step 1: Write the focused request/parse tests.**

Assert `searchDirectMessageHistory('dm-1', '"игра"', 'message-2', 20, request)` uses exactly `/api/v1/direct-messages/dm-1/search?query=%22%D0%B8%D0%B3%D1%80%D0%B0%22&before=message-2&limit=20` with `GET`, same-origin credentials and JSON accept header. A `revision: 0` result must reject with `некорректные результаты`.

- [x] **Step 2: Run the focused test before implementation.**

Run: `npm test -- src/direct_message/direct_message_search_client.spec.ts`

Expected: FAIL because the module is absent.

- [x] **Step 3: Implement the bounded client.**

Define `DirectMessageSearchResult` (`id`, `directMessageId`, `authorId`, `body`, `createdAt`, optional `editedAt`, positive `revision`) and `DirectMessageSearchPage`. Validate every returned item and date; URL-encode path/query/cursor; surface only bounded HTTP status/code errors and never log query or DM content.

- [x] **Step 4: Re-run the focused test.**

Expected: PASS.

### Task 2: Mount an accessible, pair-scoped search surface

**Files:**
- Create: `frontend/src/direct_message/DirectMessageSearch.vue`
- Modify: `frontend/src/direct_message/DirectMessageConversation.vue`
- Modify: `frontend/src/style.css`

- [x] **Step 1: Implement sequence-safe local state.**

The component receives `directMessageId`; a watcher increments a request sequence and clears prior results/cursor/error/status when that ID changes. Initial search uses the original query after only a trim-based empty check. A load-more request uses the recorded successful query, and results returning for a stale pair or sequence are ignored.

- [x] **Step 2: Render safe, keyboard-accessible results.**

Use a labelled `role="search"` form, 256-character input, pending disabled state, alert errors, polite zero/page status and a cursor-only `Показать ещё` control. Render the body through `MessageBody` only. A CSS class must be `direct-message-search` and reuse the existing dark control semantics without changing text-channel search behavior.

- [x] **Step 3: Mount the component beneath the DM heading.**

```vue
<DirectMessageSearch :direct-message-id="props.directMessageId" />
```

Preserve history, unread/read-cursor gating, send/edit/delete and reply behavior unchanged.

### Task 3: Validate and release only the web service

**Files:**
- Modify: `docs/superpowers/plans/2026-09-18-direct-message-search-ui.md`

- [x] **Step 1: Run frontend tests/build plus contract and traceability checks.**

Run `npm test`, `npm run build`, `scripts/verify-contracts.ps1`, `scripts/verify-spec-traceability.ps1`, and `git diff --check`; all must pass.

- [x] **Step 2: Inspect scoped status and file sizes without staging.**

Keep the existing dirty worktree intact and do not stage unrelated changes.

- [x] **Step 3: Release a unique non-`latest` web tag and confirm guest landing/health/session stay HTTP 200.**

Recreate only `web`. Do not log in, send a DM, issue a real DM search, or treat a guest smoke as participant ACL evidence.

**Coverage review:** This leaf supplies the missing DM-search UI side of T-043. It does not create global/cross-pair search, attachment search, event replay, real database data tests, owner login or media POC evidence.
