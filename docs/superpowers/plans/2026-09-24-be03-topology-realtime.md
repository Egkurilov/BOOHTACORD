# Topology Realtime Event Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Broadcast a revision-only `channel.updated` hint after every successful, committed topology mutation.

**Architecture:** Keep transaction ownership in the existing channel services. Wrap only admin topology HTTP handlers with a focused response observer; after the inner handler returns, publish an event only for HTTP 200/201 with a valid positive `revision` in its JSON response. Publish through the shared guild event hub so another connected client can refetch its caller-scoped topology.

**Tech Stack:** Go 1.26, net/http, JSON, in-memory event hub, focused `go test`.

---

### Task 1: Prove the response-observer boundary

**Files:**
- Create: `backend/internal/channel/publish_topology_event/http_handler_test.go`
- Create: `backend/internal/channel/publish_topology_event/http_handler.go`

- [x] **Step 1: Write failing tests** for two hub subscribers seeing one `channel.updated` event with payload exactly `{"revision":3}` after an inner handler returns `201 {"revision":3}`, the client receiving identical status/header/body, and no event on 204, 400, 409, 500, malformed JSON, missing/zero revision, or an inner-handler panic.
- [x] **Step 2: Run** `go test ./internal/channel/publish_topology_event` from `backend`; expect a package compile failure before implementation.
- [x] **Step 3: Implement `NewHandler(inner http.Handler, publisher interface{ Publish(eventhub.Event) }) http.Handler`** with a bounded copying `http.ResponseWriter` (preserve original headers/status/body), parse only the small successful JSON response, then call `publisher.Publish(eventhub.Event{EventID: uuid.NewString(), Kind: "channel.updated", OccurredAt: time.Now().UTC(), Payload: map[string]any{"revision": revision}})` after `inner.ServeHTTP` returns. An absent/invalid revision emits nothing.
- [x] **Step 4: Re-run** `go test ./internal/channel/publish_topology_event`; expect PASS.

### Task 2: Wire every topology command

**Files:**
- Modify: `backend/cmd/api/channel_routes.go`
- Test: `backend/cmd/api/channel_route_events_test.go`

- [x] **Step 1: Write a failing route-table test** that asserts the ten topology mutation methods/paths all pass through the event observer: category create, reorder, rename, delete; channel create, reorder, rename, move, archive; voice admission close. Exercise one successful response and one 409 for each registered method/path with a fake inner service when possible.
- [x] **Step 2: Run** `go test ./cmd/api -run Topology`; expect failure until wiring exists.
- [x] **Step 3: Change** `configureChannelRoutes(mux, database, sessions)` to `configureChannelRoutes(mux, database, sessions, events *eventhub.Hub)`. Wrap each of those ten handler values using `publishtopologyevent.NewHandler(handler, events)` before `mux.Handle`. Leave `GET /api/v1/channels` and `PUT /api/v1/channels/{channelID}/read-cursor` unwrapped.
- [x] **Step 4: Tell root** to change `backend/cmd/api/main.go` call to `configureChannelRoutes(mux, database, sessionService, events)` after BE-13 finishes its concurrent edit. Do not edit that shared file here.
- [x] **Step 5: Run** `go test ./internal/channel/publish_topology_event ./cmd/api`; expect PASS once root wiring lands. Run `pwsh -File scripts/verify-contracts.ps1` at repository root; expect PASS from the root-owned schema/docs.

### Task 3: Self-review

- [x] Verify event publication occurs after `ServeHTTP` returns, while existing service/repository methods return success only after transaction `Commit`.
- [x] Verify failed/stale commands have no event and event payload contains no category/channel name, ID, media or private data.
- [x] Verify both subscribed clients see the hint and the original response is unchanged.
