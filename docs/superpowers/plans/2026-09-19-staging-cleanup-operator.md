# Operator Staging Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide an explicit, private operator command that deletes only direct incomplete staging files strictly older than one hour.

**Architecture:** The existing `cleanup_stale_staging_files` leaf remains the sole filesystem deleter. A small operation wrapper accepts an absolute attachments root and a caller-provided clock, resolves only its `staging` child, and applies the fixed one-hour retention. A profile-gated Compose service exposes the compiled command; it has no database, HTTP route, scheduler, API-startup hook, or access to published files.

**Tech Stack:** Go standard-library filesystem APIs, Docker multi-stage build, Docker Compose profiles, and focused Go tests.

---

### Task 1: Fixed-window operation boundary

**Files:**
- Create: `backend/internal/storage/cleanup_stale_staging_files/operator.go`
- Modify: `backend/internal/storage/cleanup_stale_staging_files/service_test.go`

- [x] **Step 1: Write the failing operation tests**

Add tests that create an absolute attachments root with a `staging` child, an old `upload-old.part`, a file exactly one hour old, and an old non-matching file. The operation must remove exactly the old part and preserve the two other files. It must reject an empty or relative attachments root before it can resolve a working-directory `staging` folder.

```go
now := time.Date(2026, time.September, 19, 12, 0, 0, 0, time.UTC)
removed, err := RemoveExpired(root, now)
if err != nil || removed != 1 { t.Fatalf("removed = %d, error = %v", removed, err) }
if _, err := os.Stat(cutoffPart); err != nil { t.Fatal(err) }
if _, err := os.Stat(unexpected); err != nil { t.Fatal(err) }
if _, err := RemoveExpired("", now); !errors.Is(err, ErrInvalidAttachmentsDirectory) { t.Fatal(err) }
```

- [x] **Step 2: Run the focused test and confirm the red state**

Run: `go test ./internal/storage/cleanup_stale_staging_files -run 'TestRemoveExpired' -count=1`

Expected: FAIL because `RemoveExpired` and `ErrInvalidAttachmentsDirectory` do not exist.

- [x] **Step 3: Implement the fixed one-hour operation**

Create `operator.go` with this complete boundary. Do not accept a retention flag or a relative path.

```go
package cleanupstalestagingfiles

import (
    "errors"
    "path/filepath"
    "time"
)

const StagingRetention = time.Hour

var ErrInvalidAttachmentsDirectory = errors.New("invalid attachments directory")

func RemoveExpired(attachmentsDirectory string, now time.Time) (int, error) {
    if attachmentsDirectory == "" || !filepath.IsAbs(attachmentsDirectory) || now.IsZero() {
        return 0, ErrInvalidAttachmentsDirectory
    }
    service, err := New(filepath.Join(attachmentsDirectory, "staging"))
    if err != nil {
        return 0, err
    }
    return service.RemoveBefore(now.Add(-StagingRetention))
}
```

The existing `Service.RemoveBefore` continues to be responsible for direct-child enumeration, symlink skipping, regular-file checks, name matching, and physical removal.

- [x] **Step 4: Run focused tests**

Run: `go test ./internal/storage/cleanup_stale_staging_files -count=1`

Expected: PASS. It proves the one-hour strict cutoff, root validation, and preservation of non-staging files.

### Task 2: Operator-only executable and image

**Files:**
- Create: `backend/cmd/cleanup_stale_staging/main.go`
- Modify: `backend/Dockerfile`
- Modify: `compose.yaml`

- [x] **Step 1: Add the command with generic failure output**

Create `main.go`; it must never print a filename, attachment content, or underlying filesystem error.

```go
package main

import (
    "fmt"
    "os"
    "time"

    cleanupstalestagingfiles "voice-platform/backend/internal/storage/cleanup_stale_staging_files"
)

func main() {
    removed, err := cleanupstalestagingfiles.RemoveExpired(os.Getenv("ATTACHMENTS_DIRECTORY"), time.Now().UTC())
    if err != nil {
        fmt.Fprintln(os.Stderr, "could not remove stale staging files")
        os.Exit(1)
    }
    fmt.Printf("Removed %d stale staging files.\n", removed)
}
```

- [x] **Step 2: Add the binary to the existing multi-stage image**

Add one build line and one runtime copy next to the existing operator binaries:

```dockerfile
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/cleanup-stale-staging ./cmd/cleanup_stale_staging
COPY --from=build /out/cleanup-stale-staging /cleanup-stale-staging
```

- [x] **Step 3: Add a profile-gated Compose service**

Add this sibling service after `maintenance-admission`. It has only the private attachments volume and neither a PostgreSQL dependency nor a public port.

```yaml
  cleanup-stale-staging:
    profiles: [operator]
    image: ${API_IMAGE:?set API_IMAGE to a pinned image reference in .env}
    build:
      context: ./backend
    entrypoint: ["/cleanup-stale-staging"]
    environment:
      ATTACHMENTS_DIRECTORY: /var/lib/voice-platform/attachments
    volumes:
      - attachments-data:/var/lib/voice-platform/attachments
    networks: [private]
```

- [x] **Step 4: Build and validate configuration**

Run: `go build ./cmd/cleanup_stale_staging`

Expected: PASS.

Run: `$env:POSTGRES_PASSWORD='test'; $env:API_IMAGE='voice-platform-api:test'; $env:WEB_IMAGE='voice-platform-web:test'; $env:PUBLIC_HOST='voice.example.test'; $env:LIVEKIT_API_KEY='test-key'; $env:LIVEKIT_API_SECRET='test-secret'; $env:LIVEKIT_NODE_IP='127.0.0.1'; $env:LIVEKIT_PUBLIC_WS_URL='wss://voice.example.test/rtc'; docker compose config --quiet`

Expected: exit 0. Do not run the cleanup service against any real volume in local or production validation.

### Task 3: Owner procedure and verifiable non-execution

**Files:**
- Modify: `docs/ADMIN_OPERATIONS.md`
- Create: `evidence/staging-cleanup-operator-2026-09-19-001.json`
- Modify: `docs/superpowers/plans/2026-09-19-staging-cleanup-operator.md`

- [x] **Step 1: Document the exact owner command and boundary**

Add a `## Stale staging cleanup` section containing this exact command:

```bash
sudo docker compose --project-directory /opt/voice-platform -f /opt/voice-platform/compose.yaml --profile operator run --rm cleanup-stale-staging
```

State that it removes only direct, regular `staging/upload-*.part` files strictly older than one hour; it preserves symlinks, directories, unexpected names, published attachments, unattached objects, database rows, and data at the one-hour cutoff. State that it is deliberately not scheduled and must be run only after the owner decides deletion is appropriate.

- [x] **Step 2: Write an honest evidence record**

Record source validation as `PASS_STATIC`, the command’s production availability only after image deployment, and physical cleanup execution as `NOT_RUN`: no deletion will be performed merely to test this capability. Do not record paths, filenames, counts from real files, credentials, or attachment contents.

- [x] **Step 3: Update this plan and self-review**

Mark completed steps `[x]`. Verify the plan contains no placeholder language; ensure function names in tasks and source match exactly.

- [x] **Step 4: Run native verification and inspect shared worktree**

Run: `go test ./internal/storage/cleanup_stale_staging_files -count=1; go test ./... -count=1; go vet ./...; powershell -ExecutionPolicy Bypass -File scripts/verify-contracts.ps1; git diff --check; git status --short`

Expected: all validations exit 0. Inspect changed file sizes before any deployment; do not stage or commit shared-worktree files.

### Task 4: Deploy the inert operator capability

**Files:**
- Modify on server only: `/opt/voice-platform/backend/Dockerfile`, `/opt/voice-platform/backend/cmd/cleanup_stale_staging/main.go`, `/opt/voice-platform/backend/internal/storage/cleanup_stale_staging_files/operator.go`, `/opt/voice-platform/backend/internal/storage/cleanup_stale_staging_files/service_test.go`, `/opt/voice-platform/compose.yaml`, `/opt/voice-platform/docs/ADMIN_OPERATIONS.md`

- [x] **Step 1: Copy only reviewed files to a fresh remote staging directory**

Use an explicit unique `/tmp/voice-staging-cleanup-*` directory and `install` to place the reviewed files. Do not copy `.env`, volumes, credentials, or arbitrary repository content.

- [x] **Step 2: Build a pinned image and make the operator service available**

Build `voice-platform-api:release-20260919-staging-cleanup` on the server and set only `API_IMAGE` in `/opt/voice-platform/.env` to that immutable tag. Do not recreate the API for this delivery: the new binary is profile-gated, has no API runtime edge, and the existing API remains on its previously verified image until a release that changes API behavior. The Compose operator service resolves to the new pinned image.

- [x] **Step 3: Verify without removing any file**

Run `docker compose config --quiet`, confirm the operator service image exists, verify `GET https://v.bootybay.ru/api/v1/health` returns `200`, and confirm the public metrics endpoint remains `404`. Do not execute `cleanup-stale-staging`.

## Self-review

- **Spec coverage:** This advances the stale staging half of storage cleanup without treating it as authorization to clean unattached or published objects.
- **Safety:** The command has no HTTP endpoint, scheduler, database connection, or public port; it rejects relative roots; it uses the existing non-recursive, no-symlink deletion leaf.
- **Intentional gap:** Reclaiming an `UNATTACHED` object still needs its own future atomic database-and-filesystem leaf and evidence. A physical cleanup run is intentionally outside this delivery packet.
