# Common Chat Delete Realtime Implementation Plan

> **For agentic workers:** inline execution is authorized by the ongoing user request; complete each step in order and keep one trigger family in scope.

**Goal:** Keep authorized text-channel histories current across clients after a successful message deletion without broadcasting message content.

**Architecture:** The API composition wires a typed decorator around the existing delete service. The decorator publishes a bounded best-effort `message.deleted` event only after successful deletion; the browser validates the exact ID-only payload and refreshes only the active text channel. REST remains the authority and DM events remain out of scope.

Status: implemented; backend/frontend tests, contract checks, traceability, and production build pass.

**Tech Stack:** Go 1.26, Vue 3/TypeScript, Pinia, WebSocket, JSON Schema, PostgreSQL-backed existing delete service.

---

## Route brief

- Classification: `split_first`; medium packet; T-040 common-channel deletion event leaf.
- Requirements: REQ-CHAT-01, REQ-SECURITY-02; preserve hidden deleted body and never expose message content over realtime.
- Exact source edges: `chat_routes.go` wires the delete service; `delete_text_message/api/http_handler.go` calls its `Delete` interface; `event_hub.Hub.Publish` delivers bounded hints; `realtime_store.ts` validates/dispatches; `WorkspaceApp.vue` resyncs authorized REST state.
- Files: new `backend/internal/chat/delete_text_message/realtime/event_publisher.go` and focused test; `backend/cmd/api/chat_routes.go`; `contracts/realtime.schema.json`; `frontend/src/realtime/realtime_client.ts`, `realtime_store.ts`, `realtime_store.spec.ts`; new `frontend/src/workspace/active_message_resync.ts` and focused spec; `frontend/src/workspace/WorkspaceApp.vue`; `frontend/src/conversation/message_store.ts` and spec for idempotent local delete; `docs/API_AND_REALTIME.md`, `contracts/mobile-client-contract.md`, `TODO.md`.
- Ratchet: changed production files must remain under hard 120 lines; do not put new executable behavior in route aggregates; preserve the one-guild/no-private-channel boundary.
- Native checks: `go test ./cmd/api ./internal/chat/delete_text_message/realtime` from `backend`; focused and full Vitest plus Vite build from `frontend`; `scripts/verify-contracts.ps1`, `scripts/verify-spec-traceability.ps1`, and `git diff --check` from the repository root.
- Stop when failed deletes publish nothing, successful deletes publish only two IDs, invalid payloads are rejected, active matching text history refreshes, all checks pass, and TODO reflects only this completed slice.

## Execution steps

1. Add a Go publisher test whose fake deleter returns a successful result containing channel/message UUIDs; assert kind `message.deleted` and an exact two-key payload. Add a failure case asserting no event. Run the targeted Go test and observe the expected compile failure before implementing the publisher.
2. Add frontend cases for dispatching a valid `message.deleted` hint, rejecting a missing ID, and rejecting extra content such as `body`. Run the focused Vitest file and observe the new cases fail before updating the parser/store.
3. Implement a leaf decorator that invokes the existing deleter, publishes only when `err == nil`, returns the original result/error unchanged, and wire it in `chat_routes.go`.
4. Add `message.deleted` to the realtime schema and runtime event union/whitelist. Apply the same exact-payload validation as `message.created`; dispatch both message hints without treating event IDs as authority.
5. Extract and test the active-text-channel routing predicate; in `WorkspaceApp.vue`, route created/deleted hints only to `messageStore.refresh()` when no DM is selected and the event channel matches `messageStore.channelId`. Do not refresh topology or DM state for inactive text channels. Make local deletion idempotent if the realtime refresh wins the race with the DELETE response.
6. Update the API/realtime and mobile contract descriptions, T-003/T-040 TODO status, then run all native checks listed above and inspect changed file sizes/status.

## Boundaries

This packet does not add edit events, DM events, durable replay, new ACL rules, UI redesign, database schema changes, deployment, or physical POC evidence. Physical Windows/macOS tests remain owner-run manual work.
