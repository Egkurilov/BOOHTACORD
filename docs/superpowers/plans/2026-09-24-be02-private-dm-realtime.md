# Private DM Realtime Events Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Deliver DM message create, edit, and delete hints exclusively to the currently authorized pair, without message content or identifiers reaching third parties.

**Architecture:** The existing in-process hub gains an account-targeted publication method. A PostgreSQL recipient resolver rereads the canonical pair after each committed mutation and excludes blocked users. Three small mutation adapters publish ID-only hints after successful service calls. The WebSocket writer reauthenticates immediately before emitting a private hint, closing a revoked session without writing the queued event.

**Tech Stack:** Go 1.26, pgx/PostgreSQL, coder/websocket, existing `event_hub` and chat leaves.

---

Packet: `split_first`, BE-02 only. No schema migration. Existing channel `message.*` broadcasts and unrelated dirty changes in `backend/cmd/api/chat_routes.go` remain intact. Root owns shared contract and documentation files. The native checks are focused `go test` commands in `backend/`; production database integration is unavailable if local PostgreSQL is absent.

### Task 1: Account-targeted hub delivery

**Files:**
- Modify: `backend/internal/realtime/event_hub/hub.go`
- Test: `backend/internal/realtime/event_hub/hub_test.go`

- [x] Add a failing test with two tabs for account A, one for B, one administrator C, and an anonymous subscription. Publish to `[A,B]`; assert A twice and B once receive the event, while C and anonymous receive nothing.
- [x] Run `go test ./internal/realtime/event_hub -run TestPublishToAccounts -count=1`; expect failure because `PublishToAccounts` is absent.
- [x] Add `PublishToAccounts(accountIDs []string, event Event)` that creates a non-empty target set under the existing mutex and applies the existing queue overflow behavior only to matching authenticated subscriptions. Empty target sets do nothing.
- [x] Run `go test ./internal/realtime/event_hub -count=1`; expect PASS, including existing broadcast and overflow tests.

### Task 2: Current recipient ACL after the database mutation

**Files:**
- Create: `backend/internal/realtime/resolve_direct_message_recipients/postgres/repository.go`
- Test: `backend/internal/realtime/resolve_direct_message_recipients/postgres/repository_test.go`

- [x] Add a failing fake-DB test asserting query arguments `(directMessageID, actorID)`, active participant filtering, denied nonparticipant, blocked actor, and database failure.
- [x] Run `go test ./internal/realtime/resolve_direct_message_recipients/postgres -count=1`; expect failure because resolver is absent.
- [x] Implement `Resolve(ctx, directMessageID, actorID) ([]string,error)` with one parameterized SQL query. The query selects exactly the stored pair, requires the actor to belong to it and be unblocked, and reports each participant's current `blocked_at IS NULL` status. Return only active pair IDs; no role check or administrator exception. A missing pair returns no recipients.
- [x] Run the focused test; expect PASS. Never log the pair ID, actor ID, or content.

### Task 3: Publish minimal DM hints after success

**Files:**
- Create: `backend/internal/chat/send_direct_message/realtime/publisher.go`
- Create: `backend/internal/chat/edit_direct_message/realtime/publisher.go`
- Create: `backend/internal/chat/delete_direct_message/realtime/publisher.go`
- Test: corresponding `publisher_test.go` files
- Modify: `backend/cmd/api/chat_routes.go`

- [x] Write failing tests for each adapter: a successful service result publishes to the resolver's recipients only after success, a service error publishes nothing, and a recipient-query error does not convert a committed HTTP mutation into an error. Assert the payload is exactly `direct_message_id`, `message_id`, and `revision` for edit/delete, with no body or preview. Create uses exactly the two IDs.
- [x] Run `go test ./internal/chat/send_direct_message/realtime ./internal/chat/edit_direct_message/realtime ./internal/chat/delete_direct_message/realtime -count=1`; expect failure before the adapters exist.
- [x] Wrap the existing DM sender, editor, and deleter in `configureChatRoutes` while leaving existing common-channel registrations intact. Construct events with UUID event IDs and UTC timestamps, kinds `direct_message.message_created`, `direct_message.message_updated`, `direct_message.message_deleted`. Each adapter resolves recipients from PostgreSQL after the underlying service succeeds, then calls `PublishToAccounts`; empty/failed resolution sends nothing.
- [x] Run the three leaf test packages and `go test ./cmd/api -count=1`; expect PASS.

### Task 4: Stop revoked sessions before private event write

**Files:**
- Modify: `backend/internal/realtime/connect_session/event_stream.go`
- Test: `backend/internal/realtime/connect_session/event_delivery_test.go`

- [x] Add a failing WebSocket test: connect with an initially valid session, queue a private DM event after revocation, assert policy-violation closure and no DM event/ID. Keep the periodic recheck test for ordinary events.
- [x] Run `go test ./internal/realtime/connect_session -run TestRevokedSessionDoesNotReceiveQueuedDirectMessageEvent -count=1`; expect failure.
- [x] Before `wsjson.Write` of any `direct_message.message_*` event, call the configured authenticator with the original opaque cookie and a bounded context; ensure the returned account matches the subscribed account. Close on failure. Keep the existing periodic validation for other events.
- [x] Run `go test ./internal/realtime/connect_session -count=1`; expect PASS. Then run `go test ./internal/chat/... ./internal/realtime/... ./cmd/api -count=1` and review changed-file sizes and `git diff`.

Contract handoff to root: `direct_message.message_created` payload has exactly `{direct_message_id,message_id}`; `direct_message.message_updated` and `direct_message.message_deleted` add integer `revision`. All are private ID-only hints and best-effort until BE-14.
