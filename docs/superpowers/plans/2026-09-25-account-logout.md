# Account Logout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Give an authenticated user a reliable logout action that revokes the server session, stops media and realtime, clears account data, and returns to guest UI.

**Architecture:** A dedicated HTTP client sends a cookie-authenticated empty POST and treats only 204 as success. Workspace stops voice locally before revocation, then disconnects realtime, disposes Pinia stores, and emits success to App. App removes the authenticated workspace; server/network failure leaves the current session visible with an actionable error.

**Tech Stack:** Vue 3, TypeScript, Pinia, Vitest.

---

### Task 1: Logout HTTP contract

**Files:** `frontend/src/identity/logout_client.ts`, `frontend/src/identity/logout_client.spec.ts`

- [x] Test empty same-origin POST to `/auth/logout`, repeated 204 success, and non-204/server failure.
- [x] Run focused test and confirm missing-module failure.
- [x] Implement `logout(request = fetch)`; no token or credentials appear in URL/body/logs.
- [x] Run focused test and confirm success.

### Task 2: Local state boundary

**Files:** `frontend/src/identity/clear_authenticated_state.ts`, `frontend/src/identity/clear_authenticated_state.spec.ts`, `frontend/src/voice/voice_session.ts`, `frontend/src/voice/voice_session_logout.spec.ts`

- [x] Test Pinia store disposal/clearing so a second login gets fresh DM and draft state.
- [x] Test that a completed local voice disconnect releases the session object even if lease release fails.
- [x] Run focused tests to confirm failure, implement and rerun.

### Task 3: User action and guest transition

**Files:** `frontend/src/identity/ProfileSettings.vue`, `frontend/src/workspace/WorkspaceApp.vue`, `frontend/src/App.vue`, `frontend/src/workspace/logout_wiring.spec.ts`

- [x] Test action visibility, busy/error states, explicit logout wiring, and guest transition.
- [x] Keep FE-02 `sessionExpired` wiring while adding the logout event.
- [x] Stop screen/voice, POST logout, disconnect realtime, dispose stores, and show guest. On HTTP failure, keep the authenticated workspace and show the error.
- [x] Run focused tests, full `npm test`, `npm run build`, and check file size ratchet and diff. After FE-07 integration, 309/309 tests and the production build pass; WorkspaceApp is 118 lines.

### Session expiry integration

- [x] Add a focused session-expiry test and call local `disconnectLocal('SESSION_REVOKED')` only from the revoked-session callback. The guest transition proceeds immediately; ordinary WS network failure leaves LiveKit media alone.
