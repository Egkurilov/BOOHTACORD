# WebSocket Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore protected realtime state after a broken WebSocket without reloading or disconnecting healthy media.

**Architecture:** The realtime store owns reconnect timers, an in-memory durable cursor, and bounded event deduplication. Workspace handles a required REST resync; App refreshes the session when the store observes revocation. No media store is touched.

**Tech Stack:** Vue 3, Pinia, TypeScript, Vitest, browser WebSocket.

---

### Task 1: Cursor and retry policy

**Files:** `frontend/src/realtime/realtime_client.ts`, `frontend/src/realtime/reconnect_policy.ts`, `frontend/src/realtime/realtime_reconnect.spec.ts`

- [ ] Add a test that `realtimeURL(..., eventID)` appends an encoded `after` query and that only durable kinds advance the cursor.
- [ ] Run `npm test -- src/realtime/realtime_reconnect.spec.ts`; expect failure for the missing policy and cursor behavior.
- [ ] Implement exponential delays `min(15000, 500 * 2**min(attempt, 5))` with bounded jitter (`0.8 + random * 0.4`). Keep retry attempts unbounded but the interval bounded.
- [ ] Run the focused test; expect pass.

### Task 2: Lifecycle and resync

**Files:** `frontend/src/realtime/realtime_store.ts`, `frontend/src/realtime/realtime_reconnect.spec.ts`, `frontend/src/workspace/WorkspaceApp.vue`, `frontend/src/App.vue`

- [ ] Add failing fake-timer tests: abrupt close reconnects with `after`, duplicate durable event is ignored, resync clears cursor and awaits REST before later hints, disconnect cancels pending retry, revoked session exits to guest.
- [ ] Run `npm test -- src/realtime/realtime_reconnect.spec.ts`; expect behavioral failures.
- [ ] Implement one active socket generation, one retry timer, an in-memory cursor and bounded processed-ID set. On unexpected close check `/auth/session`; retry transient failures. Await sequential event handlers before acknowledging durable IDs. On `connection.resync_required` perform full REST refresh and clear the cursor.
- [ ] Wire Workspace's recovery callback to topology, selected TEXT or DM history and navigation refresh. Emit `sessionExpired` to App, which calls `refreshSession`. Never call voice media leave from this path.
- [ ] Run focused tests and `npm run build`; expect pass.

### Task 3: Native validation

**Files:** same leaf files.

- [ ] Run `npm test` and `npm run build`; expect all tests and TypeScript build to pass.
- [ ] Inspect changed file sizes and `git diff` to ensure only FE-02 behavior changed; leave staging to the parent agent.
