# BE-10 Private DM Download and Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Serve DM attachments only to the pair's authenticated participants, with forced downloads and safe normalized raster previews.

**Architecture:** A DM-specific repository authorizes actor, canonical pair, live message, attachment link and ATTACHED state in one read before opening the private file. The HTTP ingress reauthenticates the session for every request. Preview delegates raster validation and PNG normalization to the established TEXT preview implementation through a DM-only adapter.

**Tech Stack:** Go 1.26, net/http, pgx/PostgreSQL, Go image codecs.

---

### Task 1: Authorized DM metadata and private file opening

**Files:**
- Create: `backend/internal/storage/download_direct_message_attachment/service.go`
- Create: `backend/internal/storage/download_direct_message_attachment/service_test.go`
- Create: `backend/internal/storage/download_direct_message_attachment/postgres/repository.go`
- Create: `backend/internal/storage/download_direct_message_attachment/postgres/repository_test.go`
- Create: `backend/internal/storage/download_direct_message_attachment/postgres/pool_database.go`

- [ ] Write tests that invalid UUIDs never query the database, NoRows is a uniform unavailable error, and private files are not touched until authorized metadata is returned.
- [ ] Run `go test ./internal/storage/download_direct_message_attachment/...` from `backend`; expect failure before implementation.
- [ ] Implement `Input{ActorID,DirectMessageID,AttachmentID}`, `Metadata{OriginalName,StorageKey,SizeBytes}`, `Opened`, and `Service.Open`. Validate UUIDs, metadata size/name/key, and map missing private file to unavailable.
- [ ] Query `direct_messages` by route ID and participant ID; join `direct_message_attachments`, its nondeleted `direct_message_messages` row, and same-pair `attachments` in `ATTACHED` state. The actor must have an active account; the other participant can be blocked without losing the actor's history.
- [ ] Run `go test ./internal/storage/download_direct_message_attachment/...`; expect PASS.

### Task 2: Download and normalized preview ingress

**Files:**
- Create: `backend/internal/storage/download_direct_message_attachment/api/handler.go`
- Create: `backend/internal/storage/download_direct_message_attachment/api/handler_test.go`
- Create: `backend/internal/storage/preview_direct_message_attachment/service.go`
- Create: `backend/internal/storage/preview_direct_message_attachment/service_test.go`
- Create: `backend/internal/storage/preview_direct_message_attachment/api/handler.go`
- Create: `backend/internal/storage/preview_direct_message_attachment/api/handler_test.go`
- Modify: `backend/cmd/api/storage_routes.go`

- [ ] Write handlers tests: path IDs and principal reach service, unavailable maps to indistinguishable 404, malformed IDs to 400, download forces `application/octet-stream` and `attachment` disposition, both success responses use `nosniff` and `no-store`.
- [ ] Write preview adapter tests: a PNG/JPEG/GIF source becomes bounded PNG; SVG/HTML and oversized image headers produce unavailable preview; the adapter propagates DM service authorization failure.
- [ ] Run focused leaf tests; expect failure before implementation.
- [ ] Implement thin handlers and preview adapter; wire both GET routes through `sessionapi.Require(sessions)` in `storage_routes.go`. Reuse the TEXT private file store and PNG normalizer without exposing its TEXT repository.
- [ ] Run `go test ./internal/storage/download_direct_message_attachment/... ./internal/storage/preview_direct_message_attachment/... ./cmd/api` and `go vet` on these packages; expect PASS.

### Task 3: Database ACL proof and regression check

**Files:**
- Create: `backend/internal/storage/download_direct_message_attachment/postgres/integration_database_test.go`
- Create: `backend/internal/storage/download_direct_message_attachment/postgres/repository_integration_test.go`

- [ ] Add migration-backed opt-in PostgreSQL test using `VOICE_PLATFORM_TEST_DATABASE_URL`: pair participants can download; administrator outside pair, foreign pair, unattached, hidden attachment, and deleted message all yield the same unavailable error; actor can read history after peer is blocked.
- [ ] Run the leaf tests with the configured local PostgreSQL URL when available; otherwise record database integration as `NOT_RUN` without claiming PASS.
- [ ] Run `go test ./...` from `backend`; expect PASS.

Self-review: BE-10 is covered by one authorization query on each request, reauthenticated session ingress, forced binary download, bounded raster conversion, and no storage key in HTTP responses. This packet does not change OpenAPI or backlog; the integration owner updates shared contracts.
