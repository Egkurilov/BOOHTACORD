# Self-Hosted Media Revocation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every authoritative voice-access revocation terminate the matching LiveKit participant and reject any later signal connection whose token's lease is no longer active.

**Architecture:** PostgreSQL remains the authority for sessions, channels, account state and voice leases. A durable, metadata-only revocation outbox records each logical lease revocation in the same transaction; an API-owned dispatcher calls LiveKit's private RoomService `RemoveParticipant` and records whether the SFU action completed. Caddy sends every `/rtc` signal/reconnect request to an internal Go admission endpoint before proxying it to LiveKit; that endpoint verifies the signed lease-scoped token and performs a current PostgreSQL lease/session/channel/account lookup. No request path proxies RTP, RTCP, or audio/video payloads through Go.

**Tech Stack:** Go 1.26, PostgreSQL/pgx, `github.com/livekit/protocol`, Caddy 2.10, Docker Compose, LiveKit Server v1.13.7.

---

## File structure

- `docs/adr/ADR-005-self-hosted-livekit-revocation.md` records why an ingress admission guard is necessary: LiveKit documents token revocation as Cloud-only, while self-hosted `RemoveParticipant` only disconnects the current participant.
- `backend/internal/database/migrate/migrations/0028_create_voice_sfu_revocations.sql` adds the idempotent, durable metadata-only SFU-revocation outbox.
- `backend/internal/media/authorize_livekit_signal/` verifies an incoming LiveKit signal token and asks PostgreSQL whether exactly that lease remains admissible.
- `backend/internal/media/remove_livekit_participant/` owns private, signed RoomService calls and classifies an absent participant separately from a failed SFU request.
- `backend/internal/media/dispatch_voice_sfu_revocation/` claims pending outbox rows, invokes the remover and writes success or a safe retryable failure without logging a token.
- Existing voice, session, password-reset, account-ban and channel-admission leaves insert a revocation row in the transaction that changes `voice_leases`; their HTTP handlers return success only after the synchronous dispatch confirms the affected SFU action or reports a truthful pending outcome.
- `backend/cmd/api/media_revocation_routes.go` wires the internal guard and one bounded synchronous dispatch attempt; it is reachable only from the private Docker network.
- `docker/Caddyfile`, `compose.yaml`, `.env.example`, `contracts/openapi.yaml`, `docs/API_AND_REALTIME.md` and `docs/ARCHITECTURE_AND_DATA.md` define the private call path and public outcomes without exposing management credentials or token-bearing URI logs.
- `docs/POC_03_OPERATOR_RUNBOOK.md` and `evidence/` carry the real two-client validation; automated tests never claim the security gate passed.

### Task 1: Record the supported self-hosted design boundary

**Files:**
- Create: `docs/adr/ADR-003-self-hosted-livekit-revocation.md`
- Modify: `docs/ARCHITECTURE_AND_DATA.md`
- Modify: `docs/API_AND_REALTIME.md`
- Modify: `contracts/openapi.yaml`

- [ ] **Step 1: Write the failing contract assertion before changing implementation.**

Add a focused documentation/contract test in `scripts/verify-contracts.ps1` that requires both of these exact public semantics:

```powershell
$openApi = Get-Content -Raw contracts/openapi.yaml
if ($openApi -notmatch 'actual SFU participant termination') { throw 'missing truthful SFU outcome contract' }
if ($openApi -match 'short-lived token.*sufficient') { throw 'short JWT must not be claimed as sufficient' }
```

- [ ] **Step 2: Run the contract assertion and verify it fails because the current contract still calls SFU termination a POC-only future.**

Run: `pwsh -File scripts/verify-contracts.ps1`

Expected: FAIL identifying the missing confirmed/pending SFU outcome contract.

- [ ] **Step 3: Add ADR-003 with the bounded decision.**

Write the decision section as:

```markdown
## Decision

For a self-hosted LiveKit node, the API records a lease revocation and a
metadata-only SFU-revocation outbox row in one PostgreSQL transaction. It then
uses a RoomService credential only on the private Docker network to remove
`voice-lease:<lease-id>` from `voice:<channel-id>`. Caddy calls an internal
admission endpoint before every `/rtc` connection or reconnect; the endpoint
verifies the LiveKit JWT and current lease/session/channel/account state.

The guard applies only to signalling admission. LiveKit continues to carry all
RTP, RTCP and media payloads. An API response may say `pending_sfu_revocation`
when the durable job exists but RoomService has not confirmed removal; it must
not report a completed disconnect in that state.
```

Also state explicitly that a one-minute JWT is defence in depth, that management credentials are not returned to browsers, and that POC-03 is still required to prove old API-token and refreshed-SDK-token replay on the pinned server image.

- [ ] **Step 4: Replace the stale POC-only language in the architecture, API document and OpenAPI description.**

Use these precise public distinctions:

```markdown
Logical lease revocation is committed atomically. `sfu_revocation: "confirmed"`
means the private RoomService acknowledged participant removal; `"pending"`
means re-admission is already denied by the signal guard but no false claim is
made about the pre-existing media session. The response never contains a lease
ID, room name, JWT, or management credential.
```

Update the relevant `200` description in `contracts/openapi.yaml` to say that a completed operation includes confirmed SFU removal, and add a `202` response that describes the durable, retryable pending outcome. Preserve the existing administrator ACL and CSRF semantics.

- [ ] **Step 5: Run the contract assertion again.**

Run: `pwsh -File scripts/verify-contracts.ps1`

Expected: PASS.

- [ ] **Step 6: Commit the documentation-only decision.**

```powershell
git add docs/adr/ADR-003-self-hosted-livekit-revocation.md docs/ARCHITECTURE_AND_DATA.md docs/API_AND_REALTIME.md contracts/openapi.yaml scripts/verify-contracts.ps1
git commit -m "docs: define self-hosted media revocation boundary"
```

### Task 2: Persist SFU-removal work atomically with lease revocation

**Files:**
- Create: `backend/internal/database/migrate/migrations/0028_create_voice_sfu_revocations.sql`
- Modify: `backend/internal/database/migrate/run_test.go`
- Create: `backend/internal/media/dispatch_voice_sfu_revocation/repository.go`
- Create: `backend/internal/media/dispatch_voice_sfu_revocation/repository_test.go`

- [x] **Step 1: Write the migration test before the migration.**

Append this expected fragment to the `expected` table in `run_test.go`:

```go
{"CREATE TABLE IF NOT EXISTS voice_sfu_revocations", "lease_id UUID PRIMARY KEY", "completed_at TIMESTAMPTZ", "attempt_count INTEGER NOT NULL DEFAULT 0"},
```

Run: `go test ./internal/database/migrate -run TestRunExecutesEmbeddedMigrations -count=1`

Expected: FAIL because the embedded migration list has no `voice_sfu_revocations` table.

- [x] **Step 2: Add the single idempotent DDL statement.**

Create `0028_create_voice_sfu_revocations.sql` containing exactly one `CREATE TABLE IF NOT EXISTS` statement:

```sql
CREATE TABLE IF NOT EXISTS voice_sfu_revocations (
    lease_id UUID PRIMARY KEY REFERENCES voice_leases(id) ON DELETE RESTRICT,
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE RESTRICT,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    claim_token UUID,
    claimed_at TIMESTAMPTZ,
    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_error_code TEXT,
    CHECK ((completed_at IS NULL) OR (last_error_code IS NULL)),
    CHECK ((claim_token IS NULL) = (claimed_at IS NULL))
);
```

Do not store raw media JWTs, user names, account IDs, message bodies, or RoomService credentials in this table.

- [x] **Step 3: Define the outbox repository contract and tests.**

Create `repository.go` with these public values:

```go
type Item struct { LeaseID, ChannelID string }
type Store interface {
    Claim(context.Context, int) ([]Item, error)
    Confirm(context.Context, Item) error
    Retry(context.Context, Item, string) error
}
```

In `repository_test.go`, use a fake database and assert that `Claim` selects only `completed_at IS NULL`, `Confirm` sets `completed_at = now()` and clears `last_error_code`, and `Retry` increments `attempt_count` while storing only the stable code `SFU_UNAVAILABLE` rather than an upstream error string.

- [x] **Step 4: Implement the repository with bounded batches.**

Use `FOR UPDATE SKIP LOCKED` in one claiming CTE and `LIMIT $1`, then persist a fresh UUID `claim_token`, `claimed_at` and `attempt_count = attempt_count + 1` before returning claimed items. A pending item whose claim is older than 30 seconds may be reclaimed after a crashed API process. `Confirm` must update only the matching incomplete row with the same claim token. `Retry` must clear the claim, set `next_attempt_at = now() + interval '15 seconds'`, set `last_error_code = $2` and leave `completed_at` null. All errors wrap an operation name but do not interpolate a token, URL query, participant identity or LiveKit body.

- [x] **Step 5: Run focused migration and outbox tests.**

Run: `go test ./internal/database/migrate ./internal/media/dispatch_voice_sfu_revocation -count=1`

Expected: PASS.

- [ ] **Step 6: Commit the durable outbox.**

```powershell
git add backend/internal/database/migrate/migrations/0028_create_voice_sfu_revocations.sql backend/internal/database/migrate/run_test.go backend/internal/media/dispatch_voice_sfu_revocation
git commit -m "feat: persist pending LiveKit removals"
```

### Task 3: Reject revoked leases at every LiveKit signal admission

**Files:**
- Create: `backend/internal/media/authorize_livekit_signal/service.go`
- Create: `backend/internal/media/authorize_livekit_signal/service_test.go`
- Create: `backend/internal/media/authorize_livekit_signal/postgres/repository.go`
- Create: `backend/internal/media/authorize_livekit_signal/postgres/repository_test.go`
- Create: `backend/internal/media/authorize_livekit_signal/api/http_handler.go`
- Create: `backend/internal/media/authorize_livekit_signal/api/http_handler_test.go`
- Modify: `backend/cmd/api/main.go`
- Create: `backend/cmd/api/media_revocation_routes.go`

- [x] **Step 1: Write service tests for a valid signed lease token and all unsafe variants.**

The valid test token must be issued with test-only credentials, identity `voice-lease:11111111-1111-4111-8111-111111111111`, room `voice:22222222-2222-4222-8222-222222222222`, `roomJoin:true`, and `roomAdmin:false`. The fake store must receive exactly the two UUID values. Add separate tests that reject: a missing or duplicated `access_token` query value; malformed JWT; wrong API key or signature; expired token; an identity without `voice-lease:`; a non-UUID lease suffix; a missing `roomJoin`; `roomAdmin:true`; and a room which is not `voice:<uuid>`.

Run: `go test ./internal/media/authorize_livekit_signal -count=1`

Expected: FAIL because the package is absent.

- [x] **Step 2: Implement token parsing and lease admission.**

Use the protocol package rather than manually decoding JWT claims:

```go
verifier, err := auth.ParseAPIToken(rawToken)
if err != nil || verifier.APIKey() != config.APIKey { return ErrDenied }
_, claims, err := verifier.Verify(config.APISecret)
if err != nil || claims.Video == nil || !claims.Video.RoomJoin || claims.Video.RoomAdmin { return ErrDenied }
leaseID := strings.TrimPrefix(claims.Identity, "voice-lease:")
channelID := strings.TrimPrefix(claims.Video.Room, "voice:")
if claims.Identity != "voice-lease:"+leaseID || claims.Video.Room != "voice:"+channelID || uuid.Validate(leaseID) != nil || uuid.Validate(channelID) != nil { return ErrDenied }
```

Define `Store.Admit(context.Context, leaseID, channelID string) error`. Its PostgreSQL query must join `voice_leases`, `sessions`, `channels` and `users`, requiring the matching lease/channel pair, no `revoked_at`, an unrevoked issuing session, an unarchived open `VOICE` channel and an unblocked account. Map `pgx.ErrNoRows` to `ErrDenied`. Do not log the URI, JWT, account, lease or channel values.

- [x] **Step 3: Implement the private handler.**

The handler accepts only `GET /internal/media-admission` and reads `X-Forwarded-Uri`. It must require an original path of `/rtc` or `/rtc/`/`/rtc/v1` only, call the service, return `204` on admission and return `403` with an empty body on denial. It must not use a session cookie, emit JSON with a token-adjacent detail, or be mounted on the public `/api/v1` prefix.

- [x] **Step 4: Wire the private route before the public server starts.**

Create this registration function:

```go
func configureMediaRevocationRoutes(mux *http.ServeMux, database *pgxpool.Pool, config livekitsignal.Config) error {
    service, err := livekitsignal.New(config, signalpostgres.New(signalpostgres.NewPoolDatabase(database)))
    if err != nil { return err }
    mux.Handle("GET /internal/media-admission", signalapi.NewHandler(service))
    return nil
}
```

Call it from `main.go`, pass the same API key and secret already used by `livekitcredential.New`, and terminate startup with a configuration error if either constructor rejects the settings.

- [x] **Step 5: Run focused tests.**

Run: `go test ./internal/media/authorize_livekit_signal ./cmd/api -count=1`

Expected: PASS.

- [ ] **Step 6: Commit the admission guard.**

```powershell
git add backend/internal/media/authorize_livekit_signal backend/cmd/api/main.go backend/cmd/api/media_revocation_routes.go
git commit -m "feat: guard LiveKit signalling by active lease"
```

### Task 4: Remove the active participant through private RoomService

**Files:**
- Create: `backend/internal/media/remove_livekit_participant/client.go`
- Create: `backend/internal/media/remove_livekit_participant/client_test.go`
- Modify: `compose.yaml`
- Modify: `.env.example`

- [x] **Step 1: Write the client tests around a local HTTP transport.**

Use an `httptest.Server` to assert a call goes only to `/twirp/livekit.RoomService/RemoveParticipant`, has a freshly signed `Authorization: Bearer` header with `roomAdmin:true` for `voice:<channel-id>`, and serializes this payload:

```json
{"room":"voice:22222222-2222-4222-8222-222222222222","identity":"voice-lease:11111111-1111-4111-8111-111111111111"}
```

Add a test mapping a Twirp `not_found` participant response to `ErrParticipantAbsent`, and a distinct test mapping a timeout to `ErrUnavailable`. The tests must not print the bearer header or token.

Run: `go test ./internal/media/remove_livekit_participant -count=1`

Expected: FAIL because the package is absent.

- [x] **Step 2: Implement the authenticated private client.**

Create a custom `http.RoundTripper` that clones each request, mints a short RoomService token with `VideoGrant{RoomAdmin: true, Room: "voice:" + channelID}`, and sets it only on the clone. Build the generated JSON client with:

```go
client := livekit.NewRoomServiceJSONClient(config.URL, &http.Client{Transport: transport})
_, err := client.RemoveParticipant(context, &livekit.RoomParticipantIdentity{
    Room: "voice:" + channelID, Identity: "voice-lease:" + leaseID,
})
```

The config URL must parse as `http://livekit:7880` or another private HTTP(S) endpoint; reject `ws`, `wss`, public origin and empty credentials. Classify only a verified Twirp `not_found` as absent. Do not pass the RoomService endpoint through Caddy or publish port 7880.

- [ ] **Step 3: Add private configuration only.**

Add `LIVEKIT_PRIVATE_HTTP_URL=http://livekit:7880` to the `api` service environment and `.env.example`. Do not add it to `proxy`, `web`, browser environment, OpenAPI or a public endpoint.

- [ ] **Step 4: Run focused tests and resolved Compose validation.**

Run: `go test ./internal/media/remove_livekit_participant -count=1`

Expected: PASS.

Run: `$env:POSTGRES_PASSWORD='test'; $env:LIVEKIT_API_KEY='devkey'; $env:LIVEKIT_API_SECRET='test'; $env:LIVEKIT_PUBLIC_WS_URL='ws://localhost'; $env:LIVEKIT_NODE_IP='127.0.0.1'; $env:LIVEKIT_PRIVATE_HTTP_URL='http://livekit:7880'; $env:API_IMAGE='voice-platform-api:test'; $env:WEB_IMAGE='voice-platform-web:test'; docker compose config --quiet`

Expected: PASS; only the private API service receives the private management URL.

- [ ] **Step 5: Commit the RoomService client.**

```powershell
git add backend/internal/media/remove_livekit_participant compose.yaml .env.example
git commit -m "feat: remove LiveKit participant on private network"
```

### Task 5: Make every lease-revoking command enqueue and confirm SFU work

**Files:**
- Modify: `backend/internal/voice/kick_voice_participant/service.go`
- Modify: `backend/internal/voice/kick_voice_participant/service_test.go`
- Modify: `backend/internal/voice/kick_voice_participant/postgres/repository.go`
- Modify: `backend/internal/voice/kick_voice_participant/postgres/repository_test.go`
- Modify: `backend/internal/channel/close_voice_admission/postgres/repository.go`
- Modify: `backend/internal/identity/logout_user/postgres/repository.go`
- Modify: `backend/internal/identity/complete_password_reset/postgres/repository.go`
- Modify: `backend/internal/identity/admin_account/postgres/repository.go`
- Create: `backend/internal/media/dispatch_voice_sfu_revocation/service.go`
- Create: `backend/internal/media/dispatch_voice_sfu_revocation/service_test.go`
- Modify: `backend/cmd/api/admin_voice_routes.go`
- Modify: `backend/cmd/api/channel_routes.go`
- Modify: `backend/cmd/api/main.go`

- [ ] **Step 1: Write a failing dispatcher service test.**

Use a fake outbox and fake remover. Assert that an item invokes `Remove` with its lease and channel; a nil result calls `Confirm`; `ErrParticipantAbsent` also calls `Confirm`; `ErrUnavailable` calls `Retry(item, "SFU_UNAVAILABLE")` and returns `ErrPending`. The fake must never receive or retain a JWT.

Run: `go test ./internal/media/dispatch_voice_sfu_revocation -count=1`

Expected: FAIL because no dispatcher service exists.

- [ ] **Step 2: Insert an outbox row in the same SQL transaction as each active-lease update.**

For every existing `revoked AS ( UPDATE voice_leases ... RETURNING id, channel_id )` CTE, add this CTE before audit/select:

```sql
queued AS (
    INSERT INTO voice_sfu_revocations (lease_id, channel_id)
    SELECT id, channel_id FROM revoked
    ON CONFLICT (lease_id) DO NOTHING
    RETURNING lease_id
),
```

Keep the original logical revocation and audit metadata. Do not use a second transaction, trigger, background `pg_dump`, Redis queue or browser instruction as a substitute for the atomic outbox write.

- [ ] **Step 3: Make each command attempt a bounded dispatch after commit.**

The kick service calls `Dispatch(context, 1)` after its store has committed. The channel-close, logout, password-reset and ban paths do the same after their own commit. The dispatcher has a five-second context deadline derived from the request context. A confirmed or absent participant preserves the existing success response. `ErrPending` maps to `202` with:

```json
{"sfu_revocation":"pending"}
```

and all other RoomService failures map to the same truthful `202` once the outbox row is durable. Do not turn a committed access revocation back into a `500`, and do not say that the user was disconnected until `Confirm` succeeded.

- [ ] **Step 4: Add focused regression tests for all five revocation causes.**

Extend the package tests to assert their SQL contains both the established reason and `INSERT INTO voice_sfu_revocations`:

```go
for _, reason := range []string{"KICK", "CHANNEL_CLOSED", "LOGOUT", "BANNED", "SESSION_REVOKED"} {
    if !strings.Contains(statement, reason) || !strings.Contains(statement, "INSERT INTO voice_sfu_revocations") {
        t.Fatalf("missing durable SFU revocation for %s", reason)
    }
}
```

For password reset, first add the explicit `SESSION_REVOKED` lease update if it is absent, then add the same queued CTE. Tests must cover a successful dispatch, an absent LiveKit participant, and a pending SFU outcome.

- [ ] **Step 5: Run all directly affected tests.**

Run: `go test ./internal/voice/kick_voice_participant ./internal/channel/close_voice_admission ./internal/identity/logout_user ./internal/identity/complete_password_reset ./internal/identity/admin_account ./internal/media/dispatch_voice_sfu_revocation ./cmd/api -count=1`

Expected: PASS.

- [ ] **Step 6: Commit the end-to-end command wiring.**

```powershell
git add backend/internal/voice/kick_voice_participant backend/internal/channel/close_voice_admission backend/internal/identity/logout_user backend/internal/identity/complete_password_reset backend/internal/identity/admin_account backend/internal/media/dispatch_voice_sfu_revocation backend/cmd/api
git commit -m "feat: confirm SFU removal for voice revocations"
```

### Task 6: Put the guard in the signal path without logging JWT-bearing URIs

**Files:**
- Modify: `docker/Caddyfile`
- Modify: `compose.yaml`
- Modify: `docs/API_AND_REALTIME.md`
- Create: `backend/internal/media/authorize_livekit_signal/acceptance_test.go`

- [x] **Step 1: Write the Caddy configuration assertion.**

The test must read `docker/Caddyfile` and require the exact snippets `log_skip @rtc`, `forward_auth api:8080`, `uri /internal/media-admission`, and `header_up X-Forwarded-Uri {uri}`. It must reject an `@rtc` route that directly `reverse_proxy`s to LiveKit before `forward_auth`.

Run: `go test ./internal/media/authorize_livekit_signal -run TestCaddySignalRouteUsesAdmissionGuard -count=1`

Expected: FAIL before the Caddyfile changes.

- [x] **Step 2: Change only the `/rtc` route.**

Use this Caddy configuration inside the existing site `route` block:

```caddyfile
@rtc path /rtc /rtc/*
log_skip @rtc
handle @rtc {
    forward_auth api:8080 {
        uri /internal/media-admission
        header_up X-Forwarded-Uri {uri}
        header_up X-Forwarded-Method {method}
    }
    reverse_proxy livekit:7880
}
```

Retain the API, metrics and web routes. Do not publish LiveKit port 7880, add a public management endpoint, or add access logging that records `access_token` query values.

- [ ] **Step 3: Validate syntax and behavior in a disposable topology.**

Run: `docker compose config --quiet`

Expected: PASS.

Run: `docker compose up -d --build; docker compose exec proxy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile`

Expected: the Caddyfile validates.

Run a test-only signed valid token through `/rtc` and verify Caddy reaches LiveKit; then revoke its lease, retry the same raw token and assert the handshake receives `403`. Repeat with a separately refreshed SDK token. Capture neither token in command output, logs or evidence.

- [ ] **Step 4: Run the guard test suite and commit.**

Run: `go test ./internal/media/authorize_livekit_signal -count=1`

Expected: PASS.

```powershell
git add docker/Caddyfile backend/internal/media/authorize_livekit_signal docs/API_AND_REALTIME.md
git commit -m "feat: enforce LiveKit signal admission"
```

### Task 7: Execute POC-03 and record only observed evidence

**Files:**
- Create: `docs/POC_03_OPERATOR_RUNBOOK.md`
- Create: `evidence/poc-03-YYYY-MM-DD-001.json`
- Modify: `backlog/TASKS.md`

- [ ] **Step 1: Write the operator runbook before collecting evidence.**

Require two distinct signed-in browser clients: a presenter who publishes microphone or screen audio and an observer who receives it. For each of kick, ban, logout, session revocation, password reset and closed/deleted voice admission, save the pre-action API token and capture a separately refreshed SDK token after the original connection. Record the pinned LiveKit image digest, client/OS/browser version, UTC timestamps and the observer's truthful state.

- [ ] **Step 2: Execute a kick replay case.**

1. Keep both clients connected and confirm the observer receives the presenter's track.
2. Invoke administrator kick.
3. Confirm the presenter receives a disconnection and the observer's track ends.
4. Attempt `/rtc` reconnection with the pre-kick API token; record the HTTP/WebSocket denial without retaining the token.
5. Attempt reconnection with the separately refreshed SDK token; record the same type of result.
6. Request a new API credential: it must be denied while the lease is revoked. Create a new lease only after the explicit user join action and verify that it has a different lease identity.

- [ ] **Step 3: Repeat the exact replay sequence for ban, logout, session revocation, password reset and channel admission closure.**

For ban, verify new login is denied. For kick, verify the user can later manually obtain a new lease. For every case, the unaffected observer remains connected and receives a truthful remote-participant/track result. A missing second client, a token printed in an artifact, a test with only a fresh API lookup, or an unpinned image makes the record `BLOCKED` or `FAIL`, never `PASS`.

- [ ] **Step 4: Validate and classify the evidence.**

Run: `Get-Content -Raw evidence/poc-03-YYYY-MM-DD-001.json | ConvertFrom-Json | Out-Null`

Expected: PASS only for JSON syntax; set `status` to `PASS` only if every required action and both replay classes were observed by the separate observer. Otherwise use `BLOCKED` or `FAIL` and state the concrete observed condition.

- [ ] **Step 5: Update the task ledger and commit the evidence separately.**

```powershell
git add docs/POC_03_OPERATOR_RUNBOOK.md evidence/poc-03-YYYY-MM-DD-001.json backlog/TASKS.md
git commit -m "test: record POC-03 media revocation evidence"
```

## Self-review

- **Spec coverage:** Tasks 2 and 5 atomically persist lease revocations and SFU work; Tasks 3 and 6 deny old API and refreshed SDK tokens on every new self-hosted signal/reconnect; Tasks 4 and 5 force an already-connected participant off the SFU; Task 7 proves kick, ban, logout, session revocation, reset and channel closure with a separate observer. This covers REQ-ADMIN-02 and REQ-SECURITY-02 without claiming that a database update or a one-minute JWT is enough.
- **Deliberate boundary:** the durable outbox and `202` outcome preserve truth when private RoomService is unavailable. The signal guard denies later admission immediately after the database transaction. Neither component reads, relays or records media payloads.
- **Security:** raw JWTs, management tokens, room names in public responses, usernames and DM data are absent from logs, outbox rows and evidence. The LiveKit RoomService remains private; Caddy skips access logging for JWT-bearing `/rtc` URIs.
- **Remaining proof:** the POC remains a real two-client gate on the exact pinned image. Automated tests can validate route and state logic, but cannot mark T-006 or the security release gate passed.
