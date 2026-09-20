# Last Administrator Access Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the server owner reset the password of the sole active administrator through an explicit, audited CLI command when that administrator's password is lost.

**Architecture:** Keep `recover-admin` unchanged for the existing zero-active-administrator emergency. Add a separate operator-only binary whose repository update succeeds only when its target is the one and only active administrator; the transaction changes only its password and revokes that account's sessions and voice leases. The command requires an acknowledgement flag and reads the password only from standard input.

**Tech Stack:** Go 1.26, PostgreSQL/pgx, Docker Compose, Argon2id.

---

### Task 1: Isolated sole-administrator recovery capability

**Files:**

- Create: `backend/internal/identity/recover_last_administrator_access/service.go`
- Create: `backend/internal/identity/recover_last_administrator_access/service_test.go`
- Create: `backend/internal/identity/recover_last_administrator_access/postgres/repository.go`
- Create: `backend/internal/identity/recover_last_administrator_access/postgres/repository_test.go`

- [ ] **Step 1: Write the failing service and repository tests**

```go
func TestRecoverNormalizesLoginAndHashesReplacementPassword(t *testing.T) {
    accounts := &fakeAccounts{}
    err := New(accounts).Recover(context.Background(), Input{Login: "Owner", Password: "new correct horse battery staple"})
    if err != nil { t.Fatal(err) }
    if accounts.login != "owner" { t.Fatalf("login = %q", accounts.login) }
    valid, err := password.Verify("new correct horse battery staple", accounts.passwordHash)
    if err != nil || !valid { t.Fatalf("valid = %v, err = %v", valid, err) }
}

func TestRepositoryOnlyUpdatesTheSoleActiveAdministrator(t *testing.T) {
    // Assert the statement includes the target's active administrator predicate,
    // an active-administrator count of one, session and voice-lease revocation,
    // and LAST_ADMINISTRATOR_ACCESS_RECOVERED audit metadata.
}
```

- [ ] **Step 2: Run the focused tests and verify they fail because the package does not exist**

Run: `go test ./internal/identity/recover_last_administrator_access/...`

Expected: FAIL with a missing package error.

- [ ] **Step 3: Implement a bounded service and one atomic repository statement**

```go
type Accounts interface {
    RecoverSoleActiveAdministrator(context.Context, string, string) error
}

const recoverSoleActiveAdministrator = `
WITH recovered AS (
    UPDATE users
    SET password_hash = $2, updated_at = now()
    WHERE login = $1
      AND role = 'ADMINISTRATOR'
      AND blocked_at IS NULL
      AND 1 = (SELECT count(*) FROM users WHERE role = 'ADMINISTRATOR' AND blocked_at IS NULL)
    RETURNING id
), revoked AS (...), revoked_leases AS (...), audited AS (
    INSERT INTO audit_events (event_type, target_user_id)
    SELECT 'LAST_ADMINISTRATOR_ACCESS_RECOVERED', id FROM recovered
)
SELECT id::text FROM recovered`
```

Use the existing `registration.NormalizeLogin`, `registration.ValidatePassword`, `password.Hash`, pgx `ErrNoRows` mapping, transaction-level advisory lock, and session/voice-lease revocation patterns. Do not alter roles, block state, or the existing `recover_administrator` capability.

- [ ] **Step 4: Run the focused tests**

Run: `go test ./internal/identity/recover_last_administrator_access/...`

Expected: PASS.

### Task 2: Explicit operator CLI and container wiring

**Files:**

- Create: `backend/cmd/recover_last_admin_access/main.go`
- Modify: `backend/Dockerfile`
- Modify: `compose.yaml`

- [ ] **Step 1: Add command-level tests or a focused command smoke**

```bash
go run ./cmd/recover_last_admin_access --help
```

Expected: the usage states `--login`, `--password-stdin`, and `--confirm-sole-active-administrator-access-recovery`; it must not print or accept a password flag.

- [ ] **Step 2: Implement the explicit confirmation boundary**

```go
confirmed := flag.Bool("confirm-sole-active-administrator-access-recovery", false,
    "confirm recovery of access to the sole active administrator")
if *login == "" || !*passwordStdin || !*confirmed {
    fmt.Fprintln(os.Stderr, "usage: recover-last-admin-access --login <login> --password-stdin --confirm-sole-active-administrator-access-recovery")
    os.Exit(2)
}
```

Read the replacement secret through the shared `password_input` reader, invoke the new service, and report only a non-secret completion message. Compile it to `/recover-last-admin-access`; add a `recover-last-admin-access` Compose service under the `operator` profile with the same database-only network and dependency pattern as the other operator CLIs.

- [ ] **Step 3: Verify build and Compose shape**

Run: `go build ./cmd/recover_last_admin_access; docker compose --profile operator config`

Expected: successful Go build; the operator profile includes the new one-shot service and no public port.

### Task 3: Operational contract and production recovery

**Files:**

- Modify: `docs/adr/ADR-004-administrator-bootstrap-and-recovery.md`
- Modify: `docs/ADMIN_OPERATIONS.md`

- [ ] **Step 1: Document the distinct recovery paths**

State that `recover-admin` is retained only for zero active administrators. State that `recover-last-admin-access` can act only on the sole currently active administrator, requires the exact confirmation flag, resets its password, revokes sessions and voice leases, and audits the event. Include a stdin-only server-owner command; never put the secret in command arguments or documentation.

- [ ] **Step 2: Run project checks**

Run: `go test ./internal/identity/recover_administrator/... ./internal/identity/recover_last_administrator_access/...; powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1; powershell -ExecutionPolicy Bypass -File scripts/verify-contracts.ps1`

Expected: all checks pass.

- [ ] **Step 3: Release and verify the owner recovery**

Build a new pinned API image, update the server release, run the new operator command with the owner-approved replacement password through stdin, then verify only that the health endpoint is 200 and a login succeeds. Do not output the password, session cookie, token, or reset data.

### Review checklist

- [ ] REQ-AUTH-04 remains true: bootstrap stays immutable; access recovery is an audited owner CLI.
- [ ] REQ-AUTH-02 remains true: the new password is Argon2id-hashed and old sessions are revoked.
- [ ] The command cannot update a member, a blocked account, a target different from the sole active administrator, or any deployment with two or more active administrators.
- [ ] No code path logs a password, session token, or reset token.
