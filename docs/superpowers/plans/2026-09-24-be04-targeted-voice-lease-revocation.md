# Targeted Voice Lease Revocation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Emit `voice.lease_revoked` with only the owner's lease ID and reason, independently of SFU removal.

**Architecture:** Each existing revoke mutation already commits a `voice_sfu_revocations` row with its lease. A separate notification claim on that durable row reads the owning `voice_leases.user_id`, writes a durable targeted event through BE-14's hub, then marks emission. A crash between journal write and mark may repeat the same deterministic event ID; SFU dispatch remains independent.

**Tech Stack:** Go 1.26, pgx/PostgreSQL, WebSocket event hub, PowerShell native checks.

---

### Task 1: Notification outbox state and claim tests

**Files:**
- Create: `backend/internal/database/migrate/migrations/0034_add_voice_lease_revocation_notification.sql`
- Create: `backend/internal/voice/notify_lease_revocation/repository_test.go`
- Create: `backend/internal/voice/notify_lease_revocation/repository.go`
- Create: `backend/internal/voice/notify_lease_revocation/pool_database.go`

- [ ] **Step 1: Write failing tests** for a bounded claim that selects only rows whose `notification_emitted_at IS NULL`, joins `voice_leases` for `user_id` and `revocation_reason`, uses `FOR UPDATE SKIP LOCKED`, and claims with a UUID token. Cover mark-by-claim-token and affected-row check.
- [ ] **Step 2: Run** `go test ./internal/voice/notify_lease_revocation` from `backend`; expect failure before implementation.
- [ ] **Step 3: Add migration** columns `notification_claim_token`, `notification_claimed_at`, `notification_emitted_at` and paired-column constraint. Implement `Claim(ctx, limit)` and `MarkEmitted(ctx, item)` with SQL CTE claim and token-bound update. The claim is independent of `completed_at` so SFU failure and success both notify. Use `ADD COLUMN IF NOT EXISTS`, drop/re-add the named constraint, and `CREATE INDEX IF NOT EXISTS` because startup replays migrations.
- [ ] **Step 4: Rerun** the leaf tests; expect PASS.

### Task 2: Private event service and retry semantics

**Files:**
- Create: `backend/internal/voice/notify_lease_revocation/service_test.go`
- Create: `backend/internal/voice/notify_lease_revocation/service.go`

- [ ] **Step 1: Write failing tests** with owner, outsider and administrator subscriptions. Assert only owner receives `voice.lease_revoked`, payload is exactly `{lease_id,reason}`, and the event ID is deterministic across repeated emission. Table-test `TRANSFER`, `KICK`, `CHANNEL_CLOSED`, `SESSION_REVOKED`, `BANNED`, `LOGOUT`, `VOLUNTARY_LEAVE`. Simulate failed `MarkEmitted`: retry publishes the same ID. Simulate pending SFU by leaving `completed_at` unset.
- [ ] **Step 2: Run** `go test ./internal/voice/notify_lease_revocation`; expect FAIL.
- [ ] **Step 3: Implement** `Service.Dispatch(ctx, limit)` that claims, targets `PublishToAccountsDurable(ctx, []string{item.UserID}, event)`, and only then marks emission on a nil result. On journal failure leave the row pending for stale-claim retry. Set `EventID` to `uuid.NewSHA1(uuid.NameSpaceOID, []byte("voice.lease_revoked:"+item.LeaseID)).String()` and `OccurredAt` to the durable `requested_at`.
- [ ] **Step 4: Rerun** the leaf tests; expect PASS.

### Task 3: Worker wiring and database behavior

**Files:**
- Modify: `backend/cmd/api/voice_sfu_revocation_worker.go`
- Test: `backend/cmd/api/voice_sfu_revocation_worker_test.go`
- Root-owned wiring: `backend/cmd/api/main.go`
- Test: `backend/internal/voice/notify_lease_revocation/integration_database_test.go`

- [ ] **Step 1: Test** that notification dispatch runs even if SFU returns `ErrPending`, and notification failure does not prevent SFU removal.
- [ ] **Step 2: Extend** worker loop to invoke notification dispatch independently before SFU dispatch; give root the exact `main.go` constructor wiring.
- [ ] **Step 3: Add opt-in PostgreSQL integration test** using `VOICE_PLATFORM_TEST_DATABASE_URL`, isolated schema and all migrations; exercise transactional revoke rollback, duplicate claim, retry and owner/reason lookup.
- [ ] **Step 4: Run** `go test ./internal/voice/notify_lease_revocation ./cmd/api` and opt-in integration when database is available; report `NOT_RUN` otherwise.

### Self-review

- All seven persisted reasons covered; no foreign lease ID in a non-owner subscription.
- Publish occurs after the source revoke transaction commits; retries share event ID.
- `notification_emitted_at` records successful journal insertion and server emission, not SFU removal or client acknowledgement.
- No source mutation needs to touch the SFU outbox contract; BE-14 can later replay durable events.
