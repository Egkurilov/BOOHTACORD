# Typed Realtime Application Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply private DM, topology and voice revocation hints to the right local state, using protected REST reads and strict lease matching.

**Architecture:** Validate payloads at the realtime parser; the store delivers only typed events. Three small Workspace leaves route DM, topology and voice hints. A matching revoked lease disconnects local LiveKit media without retrying a server release for an already revoked lease.

**Tech Stack:** Vue 3, Pinia, TypeScript, Vitest, LiveKit Client.

---

### Task 1: Validate and dispatch typed hints

**Files:** `frontend/src/realtime/realtime_client.ts`, `frontend/src/realtime/realtime_store.ts`, `frontend/src/realtime/realtime_event_contract.spec.ts`

- [ ] Test exact DM, channel and voice payloads; reject missing IDs, bad revision/reason, and secret/body fields.
- [ ] Run focused Vitest and verify red behavior.
- [ ] Add exact payload validation and dispatch all validated schema kinds to the event queue; remove redundant TEXT validation from the socket store.
- [ ] Run focused Vitest and verify green behavior.

### Task 2: DM and topology state

**Files:** `frontend/src/workspace/direct_message_realtime.ts`, `frontend/src/workspace/topology_realtime.ts`, `frontend/src/workspace/workspace_realtime.ts`, family specs.

- [ ] Test DM navigation refresh for every DM hint, history refresh only for matching active DM, and topology refresh only for `channel.updated`.
- [ ] Run focused Vitest and verify missing helper failures.
- [ ] Add checked protected reads; route events in Workspace and await them before the durable cursor advances.
- [ ] Run focused Vitest and verify green behavior.

### Task 3: Voice revocation

**Files:** `frontend/src/voice/voice_session.ts`, `frontend/src/voice/connection_store.ts`, `frontend/src/workspace/voice_lease_realtime.ts`, `frontend/src/workspace/WorkspaceApp.vue`, family specs.

- [ ] Test foreign lease no-op, matching lease disconnect and reason, and race with normal leave.
- [ ] Run focused Vitest and verify red behavior.
- [ ] Add local revoke teardown without release request; reset local store and navigation after matching event.
- [ ] Run focused tests and TypeScript build.

### Task 4: Native checks

**Files:** all above.

- [ ] Run focused tests, full `npm test`, `npm run build`, then inspect diff and file sizes. Leave stage/commit/push to root.
