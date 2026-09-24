# Live Text-Message Realtime Delivery Plan

**Goal:** Deliver safe `message.created` hints to authenticated WebSocket clients and refresh only the currently open matching text channel.

**Scope:** One in-process bounded fan-out for this single-API deployment. Events contain only `channel_id` and `message_id`; no DM, message body, author, attachment, or durable replay. Queue overflow emits `connection.resync_required` and resumes delivery after the client is told to reload protected state.

**Route:** `split_first`, leaf `text_message_created_realtime`. Preserve existing cookie authentication, Origin middleware, session revalidation, and REST ACL. No physical POC/evidence claims.

## Files

- Create `backend/internal/realtime/event_hub/hub.go` and focused tests.
- Modify `backend/internal/realtime/connect_session/http_handler.go`; add focused WebSocket delivery tests and a small `event_stream.go` helper if needed to stay below the file ratchet.
- Modify `backend/cmd/api/chat_routes.go`, `backend/cmd/api/realtime_routes.go`, and `backend/cmd/api/main.go` to share one hub.
- Modify `frontend/src/realtime/realtime_store.ts`, `frontend/src/workspace/WorkspaceApp.vue`, and their existing focused tests.
- Update `contracts/realtime.schema.json`, `contracts/mobile-client-contract.md`, `docs/API_AND_REALTIME.md`, and the T-003 status line in `TODO.md`.

## TDD sequence

- [x] Add hub tests proving fan-out to independent subscribers, bounded queues, and an overflow signal; the focused test failed before implementation.
- [x] Implement the synchronized hub and overflow acknowledgement; its tests pass.
- [x] Add a WebSocket test for safe `message.created` delivery; retain the existing session-revalidation test, while overflow/resync recovery is covered by the bounded-hub test.
- [x] Subscribe before `connection.ready`, stream events, and use REST resync as recovery for a dropped hint.
- [x] Wrap the existing text-message creator at route composition; publish only after successful creation, with the two-ID payload.
- [x] Test browser event dispatch and payload validation; refresh visible text history only when its channel ID matches.
- [x] Constrain the event schema and document the payload and non-durable semantics.
- [x] Run focused Go tests, `go test ./...`, `go vet ./...`, all frontend tests/build, `scripts/verify-contracts.ps1`, and `scripts/verify-spec-traceability.ps1`.

**Stop condition:** Automated delivery and contract checks pass; mark only the T-003 text-message publication slice complete. Event replay, other event families, PostgreSQL/LiveKit integration, production image/runtime checks, and the owner-run Windows/macOS physical POC remain open.
