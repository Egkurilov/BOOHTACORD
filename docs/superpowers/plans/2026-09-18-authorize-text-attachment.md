# Authorize Text Attachment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide the server-side authorization leaf that must admit a staged attachment only for an active account targeting an available text channel.

**Architecture:** The service validates UUID inputs before issuing I/O. Its PostgreSQL adapter uses one parameterized row query joining `users` and `channels`, requiring `blocked_at IS NULL`, `kind = 'TEXT'` and `archived_at IS NULL`; all zero-row conditions become one unavailable-target error. The leaf has no HTTP route or filesystem effect, so a future staging command can invoke it before receiving bytes and recheck its equivalent predicate during metadata persistence.

**Tech Stack:** Go, pgx, focused service/repository tests.

---

### Task 1: Define the authorization contract

**Files:**
- Create: `backend/internal/storage/authorize_text_attachment/service.go`
- Create: `backend/internal/storage/authorize_text_attachment/service_test.go`

- [x] **Step 1: Write failing domain tests.**

```go
_, err := service.Authorize(context.Background(), Input{ActorID: userID, ChannelID: channelID})
if err != nil || store.input.ActorID != userID { t.Fatal("must delegate valid target") }

_, err = service.Authorize(context.Background(), Input{ActorID: "invalid", ChannelID: channelID})
if !errors.Is(err, ErrInvalidInput) || store.called { t.Fatal("must reject before store") }
```

- [x] **Step 2: Run the package before implementation.**

Run: `go test ./internal/storage/authorize_text_attachment`

Expected: FAIL because the package is absent.

- [x] **Step 3: Implement UUID validation and unavailable-target mapping.**

```go
type Store interface { Authorize(context.Context, Input) error }

func (service Service) Authorize(ctx context.Context, input Input) error {
    if !validUUID(input.ActorID) || !validUUID(input.ChannelID) { return ErrInvalidInput }
    if err := service.store.Authorize(ctx, input); errors.Is(err, ErrTargetUnavailable) { return ErrTargetUnavailable }
    return err
}
```

- [x] **Step 4: Run the focused service tests.**

Run: `go test ./internal/storage/authorize_text_attachment`

Expected: PASS.

### Task 2: Make the PostgreSQL predicate the authority

**Files:**
- Create: `backend/internal/storage/authorize_text_attachment/postgres/repository.go`
- Create: `backend/internal/storage/authorize_text_attachment/postgres/pool_database.go`
- Create: `backend/internal/storage/authorize_text_attachment/postgres/repository_test.go`

- [x] **Step 1: Write a failing repository test for the joined predicate and zero-row mapping.**

```go
for _, fragment := range []string{"users.blocked_at IS NULL", "channels.kind = 'TEXT'", "channels.archived_at IS NULL", "users.id = $1", "channels.id = $2"} {
    if !strings.Contains(database.statement, fragment) { t.Fatal(fragment) }
}
```

- [x] **Step 2: Implement one parameterized `SELECT 1` query.**

```sql
SELECT 1
FROM users
JOIN channels ON channels.id = $2
WHERE users.id = $1
  AND users.blocked_at IS NULL
  AND channels.kind = 'TEXT'
  AND channels.archived_at IS NULL
```

Map `pgx.ErrNoRows` to `ErrTargetUnavailable`; wrap only unexpected database errors.

- [x] **Step 3: Run the focused repository tests.**

Run: `go test ./internal/storage/authorize_text_attachment/postgres`

Expected: PASS.

### Task 3: Document the preflight boundary and validate

**Files:**
- Modify: `docs/ARCHITECTURE_AND_DATA.md`

- [x] **Step 1: State that preflight authorization does not replace final metadata authorization.**

Mention the same target predicate must be applied again by the later attachment insert after bytes have been staged.

- [x] **Step 2: Run native checks.**

Run: `go test ./...`; `go vet ./...`; `powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1`

Expected: PASS.

## Self-review

- No client-supplied channel ID grants access by itself; active account and current channel state are checked on the server.
- The SQL predicate does not test an administrator role, so it cannot introduce an admin-only attachment bypass.
- Multipart input, file reads, attachment rows, atomic moves, DM targets, message links and downloads remain outside this leaf.
