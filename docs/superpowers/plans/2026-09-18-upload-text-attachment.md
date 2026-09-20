# Upload Text Attachment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide an authenticated, rate-limited multipart endpoint that stages and finalizes one private text-channel attachment with byte, disk and ACL controls.

**Architecture:** An orchestration leaf first preflights the current text-channel ACL, streams only the multipart file part into the reservation-protected staging writer, and finalizes metadata with the second SQL ACL predicate. The API ingress admits one `file` part and maps errors without exposing a path or storage key. Startup creates sibling `staging` and `unattached` directories inside the private attachment volume, so the final `os.Rename` remains atomic; Linux capacity snapshots use that same volume.

**Tech Stack:** Go 1.26, standard `mime/multipart`, pgx, existing Go HTTP session/origin/rate-limit middleware, PostgreSQL and private Docker volume.

---

### Task 1: Upload orchestration service

**Files:**
- Create: `backend/internal/storage/upload_text_attachment/service.go`
- Create: `backend/internal/storage/upload_text_attachment/service_test.go`
- Create: `backend/internal/storage/upload_text_attachment/test_support_test.go`

- [x] **Step 1: Write failing service tests.** Assert valid input calls authorizer, stager, then finalizer with the measured staging result; assert preflight denial does not read/stage; assert finalization failure removes the private temporary path.
- [x] **Step 2: Run `go test ./internal/storage/upload_text_attachment`.** Observed the expected absent-symbol build failure.
- [x] **Step 3: Implement the narrow orchestration.** Keep only source streaming, current-target preflight, staging, finalization and best-effort cleanup; preserve wrapped `ErrTargetUnavailable`, `ErrInsufficientStorage` and size errors for HTTP mapping.
- [x] **Step 4: Run the focused test.** PASS.

### Task 2: Multipart HTTP ingress and public contract

**Files:**
- Create: `backend/internal/storage/upload_text_attachment/api/http_handler.go`
- Create: `backend/internal/storage/upload_text_attachment/api/http_handler_test.go`
- Modify: `contracts/openapi.yaml`

- [x] **Step 1: Write failing handler tests.** A current session and `file` part must pass actor, path channel, sanitized file name and streaming body to the uploader; missing part is rejected without exposing storage state.
- [x] **Step 2: Run `go test ./internal/storage/upload_text_attachment/api`.** Observed the expected absent-handler build failure.
- [x] **Step 3: Implement one-file multipart handling.** Apply a bounded total reader, reject an absent/non-file first part, stream rather than `ParseMultipartForm`, map full storage to `INSUFFICIENT_STORAGE`, and return metadata without `storage_key` or filesystem location.
- [x] **Step 4: Add `POST /api/v1/channels/{channelID}/attachments` to OpenAPI.** Use `multipart/form-data`, require its `file` field, document current channel ACL, and define only attachment ID/name/size metadata.
- [x] **Step 5: Run focused tests and `scripts/verify-contracts.ps1`.** PASS.

### Task 3: Private-volume route composition and deployment inputs

**Files:**
- Create: `backend/cmd/api/storage_routes.go`
- Modify: `backend/cmd/api/main.go`
- Modify: `compose.yaml`
- Modify: `docs/ARCHITECTURE_AND_DATA.md`

- [x] **Step 1: Add route-composition compile coverage first.** `go test ./cmd/api` compiles the API binary dependency graph on this PC using the non-Linux filesystem guard.
- [x] **Step 2: Compose the route.** Create `staging` and `unattached` directories below `ATTACHMENTS_DIRECTORY`, initialize the Linux filesystem reservation manager and PostgreSQL stores, protect the endpoint with session, origin and a dedicated upload limiter, and terminate startup on invalid storage configuration.
- [x] **Step 3: Pass `ATTACHMENTS_DIRECTORY=/var/lib/voice-platform/attachments` through Compose.** Do not publish the volume, PostgreSQL, or a storage path.
- [x] **Step 4: Document ingress and privacy boundaries.** State that upload metadata does not grant download access and the endpoint has no DM counterpart yet.
- [x] **Step 5: Run `go test ./...`, `go vet ./...`, contract and traceability checks, then inspect changed sizes/status.** PASS on 2026-09-18; no files were staged or committed.
