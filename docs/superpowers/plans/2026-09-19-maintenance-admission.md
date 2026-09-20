# Maintenance Admission Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent new browser admission during a trusted deployment while showing users an explicit Russian maintenance warning, without interrupting existing media more than the deployment itself requires.

**Architecture:** PostgreSQL owns a singleton maintenance state, changed only by a server-local CLI. The Go API reads that state before registration, login, voice-lease issuance and private LiveKit signal admission; safe reads and logout remain available. The deploy script enables state before migrations, waits for the warning interval, then disables it only after health succeeds. Vue polls a public, metadata-only status endpoint and renders a non-dismissible warning.

**Tech Stack:** Go 1.26, PostgreSQL 17 migration, Vue 3/TypeScript/Vite, Docker Compose, Bash, GitHub Actions.

---

### Task 1: Persist a singleton maintenance state

**Files:**
- Create: `backend/internal/database/migrate/migrations/0029_create_maintenance_admission.sql`
- Create: `backend/internal/maintenance/admission/service.go`
- Create: `backend/internal/maintenance/admission/service_test.go`
- Create: `backend/internal/maintenance/admission/postgres/repository.go`
- Create: `backend/internal/maintenance/admission/postgres/repository_test.go`

- [x] **Step 1: Write failing service and repository tests.**

```go
func TestServiceRejectsAdmissionOnlyWhenMaintenanceIsActive(t *testing.T) {
  service := New(fakeStore{active: true})
  if err := service.RequireOpen(context.Background()); !errors.Is(err, ErrMaintenanceActive) {
    t.Fatalf("expected ErrMaintenanceActive, got %v", err)
  }
}

func TestRepositoryChangesOnlySingletonState(t *testing.T) {
  repository := New(&fakeDatabase{})
  if err := repository.Set(context.Background(), true); err != nil { t.Fatal(err) }
  if !strings.Contains(fake.statement, "WHERE singleton = true") { t.Fatal("must update singleton") }
}
```

- [x] **Step 2: Run focused tests and confirm they fail because the package does not exist.**

Run: `go test ./internal/maintenance/admission ./internal/maintenance/admission/postgres -count=1`

Expected: FAIL with package or symbol missing.

- [x] **Step 3: Add immutable migration and narrow repository.**

```sql
CREATE TABLE IF NOT EXISTS maintenance_admission (
    singleton BOOLEAN PRIMARY KEY DEFAULT true CHECK (singleton),
    active BOOLEAN NOT NULL DEFAULT false,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO maintenance_admission (singleton, active)
VALUES (true, false)
ON CONFLICT (singleton) DO NOTHING;
```

Implement `Active(context.Context) (bool, error)` and `Set(context.Context, bool) error` with parameterized SQL. `Set` must update only `singleton = true`; it stores no actor name, password, session, media credential or message.

- [x] **Step 4: Implement the service and rerun focused tests.**

`RequireOpen` returns only `ErrMaintenanceActive` for a true state; database failures remain wrapped operational errors. `Set` accepts the explicit boolean supplied by the local CLI.

Run: `go test ./internal/maintenance/admission ./internal/maintenance/admission/postgres -count=1`

Expected: PASS.

- [ ] **Step 5: Commit the persistence leaf.**

```bash
git add backend/internal/database/migrate/migrations/0029_create_maintenance_admission.sql backend/internal/maintenance/admission
git commit -m "feat: persist deployment maintenance admission"
```

### Task 2: Enforce admission and expose only public maintenance state

**Files:**
- Create: `backend/internal/maintenance/admission/api/http_handler.go`
- Create: `backend/internal/maintenance/admission/api/http_handler_test.go`
- Create: `backend/internal/maintenance/admission/middleware.go`
- Create: `backend/internal/maintenance/admission/middleware_test.go`
- Modify: `backend/cmd/api/main.go`
- Modify: `backend/cmd/api/voice_lease_routes.go`
- Modify: `backend/cmd/api/media_revocation_routes.go`

- [x] **Step 1: Write failing HTTP and middleware tests.**

```go
func TestStatusHandlerReturnsOnlyActiveFlag(t *testing.T) {
  recorder := httptest.NewRecorder()
  NewStatusHandler(fakeStore{active: true}).ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/v1/maintenance", nil))
  if recorder.Code != http.StatusOK || recorder.Body.String() != "{\"active\":true}\n" { t.Fatal("unexpected status") }
}

func TestMiddlewareRejectsNewVoiceLeaseDuringMaintenance(t *testing.T) {
  handler := RequireOpen(fakeService{err: ErrMaintenanceActive})(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { t.Fatal("must not call next") }))
  recorder := httptest.NewRecorder()
  handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/api/v1/voice/channels/channel/leases", nil))
  if recorder.Code != http.StatusServiceUnavailable { t.Fatal("expected 503") }
}
```

- [x] **Step 2: Run these tests and confirm the ingress does not exist.**

Run: `go test ./internal/maintenance/admission/... -count=1`

Expected: FAIL with handler or middleware missing.

- [x] **Step 3: Add exact routing and protection boundaries.**

Register `GET /api/v1/maintenance` before session-required routes and return exactly `{"active":<bool>}`. Install an admission middleware only around registration, login, voice lease creation and `GET /internal/media-admission`; it returns a stable `503` JSON error code `MAINTENANCE` without details. Do not block health, logout, authenticated reads, messages, existing WebSocket connections or private RoomService removal.

- [x] **Step 4: Run targeted API and regression tests.**

Run: `go test ./internal/maintenance/admission/... ./cmd/api ./internal/identity/login_user ./internal/identity/register_user ./internal/voice/acquire_voice_lease ./internal/media/authorize_livekit_signal -count=1`

Expected: PASS.

- [ ] **Step 5: Commit the API admission leaf.**

```bash
git add backend/internal/maintenance/admission backend/cmd/api/main.go backend/cmd/api/voice_lease_routes.go backend/cmd/api/media_revocation_routes.go
git commit -m "feat: gate new admission during maintenance"
```

### Task 3: Add server-local switch and deploy ordering

**Files:**
- Create: `backend/cmd/maintenance_admission/main.go`
- Modify: `backend/Dockerfile`
- Modify: `compose.yaml`
- Modify: `scripts/deploy-images.sh`
- Modify: `scripts/deploy-images.test.sh`

- [x] **Step 1: Write failing CLI parsing and deploy-order tests.**

```go
func TestParseModeRequiresExactlyEnableOrDisable(t *testing.T) {
  if _, err := parseMode([]string{"--enable", "--disable"}); err == nil { t.Fatal("ambiguous mode accepted") }
}
```

Extend `scripts/deploy-images.test.sh` to require this order: `maintenance-admission --enable`, a 15-second wait, image pull, migration, workload restart, proxy validation, health check, then `maintenance-admission --disable`. Its fake command log must show that a health failure does not issue disable.

- [x] **Step 2: Run tests and confirm the command/order is absent.**

Run: `go test ./cmd/maintenance_admission -count=1; bash scripts/deploy-images.test.sh`

Expected: first command FAILS because the CLI does not exist; Bash test FAILS on missing maintenance calls.

- [x] **Step 3: Implement the local command and Compose profile.**

The CLI accepts exactly one of `--enable` and `--disable`, connects with `DATABASE_URL`, changes only the singleton value and writes generic success text. Build it as `/maintenance-admission`; add a Compose `maintenance-admission` service under the `operator` profile with that entrypoint and `DATABASE_URL`. It must not accept passwords, tokens or external request parameters.

- [x] **Step 4: Make deployment fail closed.**

Before pulling release images, invoke `docker compose --profile operator run --rm --no-deps maintenance-admission --enable`, then `sleep 15`. Perform the existing pull/migration/restart/network/Caddy/health sequence. Invoke `--disable` only after the health command succeeds. A failed deploy preserves maintenance mode and emits no secrets.

- [x] **Step 5: Run command, deploy-script and Compose validations.**

Run: `go test ./cmd/maintenance_admission -count=1; bash scripts/deploy-images.test.sh; docker compose --env-file .env.example --profile operator config --quiet`

Expected: PASS.

- [ ] **Step 6: Commit the deployment orchestration leaf.**

```bash
git add backend/cmd/maintenance_admission backend/Dockerfile compose.yaml scripts/deploy-images.sh scripts/deploy-images.test.sh
git commit -m "feat: gate release admission during maintenance"
```

### Task 4: Render a public maintenance warning

**Files:**
- Create: `frontend/src/maintenance/status_client.ts`
- Create: `frontend/src/maintenance/status_client.spec.ts`
- Create: `frontend/src/maintenance/MaintenanceBanner.vue`
- Modify: `frontend/src/App.vue`
- Modify: `frontend/src/style.css`

- [x] **Step 1: Write failing status-client tests.**

```ts
it('accepts only an active boolean from the maintenance endpoint', async () => {
  await expect(loadMaintenanceStatus(fakeJson({ active: true }))).resolves.toEqual({ active: true })
  await expect(loadMaintenanceStatus(fakeJson({ active: 'true' }))).rejects.toThrow('некорректный')
})
```

- [x] **Step 2: Run the test and confirm it fails.**

Run: `npm test -- --run src/maintenance/status_client.spec.ts`

Expected: FAIL because the client does not exist.

- [x] **Step 3: Implement poll and banner.**

`loadMaintenanceStatus` requests `/api/v1/maintenance` with `credentials: 'same-origin'` and validates only a boolean `active`. `App.vue` loads it on mount and every 5 seconds, clearing the interval on unmount. When active, render `MaintenanceBanner` before the guest or authenticated surface with text `Идёт обновление: новые входы и подключения к голосу временно приостановлены.` The banner has `role="status"`; it does not display internal paths, schedule, operator identity or a countdown.

- [x] **Step 4: Run client tests and production build.**

Run: `npm test -- --run src/maintenance/status_client.spec.ts; npm run build`

Expected: PASS.

- [ ] **Step 5: Commit the warning UI leaf.**

```bash
git add frontend/src/maintenance frontend/src/App.vue frontend/src/style.css
git commit -m "feat: show maintenance admission warning"
```

### Task 5: Verify a release on controlled infrastructure

**Files:**
- Create: `evidence/deployment-maintenance-YYYY-MM-DD-001.json`
- Modify: `docs/ADMIN_OPERATIONS.md`

- [x] **Step 1: Add an owner runbook section with exact expected states.**

Document that the owner starts a trusted `main` release, confirms the banner from a second browser, confirms registration/login/new voice lease receive maintenance refusal, confirms existing media does not receive a synthetic disconnect before restart, and observes health after disable. Do not record raw cookies, JWTs, passwords, private keys or host fingerprints.

- [x] **Step 2: Execute and classify evidence.**

Record pinned image digests, UTC times, `PASS`/`FAIL` outcomes and the two browser roles. Use `BLOCKED` if GitHub repository secrets, a trusted push, or second observer is unavailable.

- [x] **Step 3: Validate JSON and run all delivery checks.**

Run: `Get-Content -Raw evidence/deployment-maintenance-YYYY-MM-DD-001.json | ConvertFrom-Json | Out-Null; pwsh -NoProfile -File scripts/verify-contracts.ps1; pwsh -NoProfile -File scripts/verify-spec-traceability.ps1`

Expected: syntax and static checks PASS; release evidence remains truthful.

## Self-review

- **Spec coverage:** Tasks 1–3 create an authoritative server-side maintenance switch and deploy ordering; Task 4 provides the required browser warning; Task 5 supplies the required controlled-release evidence. No task adds a backup, public management interface, Redis, `latest` image or Go media proxy.
- **Gaps intentionally not claimed:** A GitHub publish/deploy cannot be marked PASS without a connected repository, configured secrets and a trusted push. The feature does not prove POC-01, POC-03 or capacity.
- **Type consistency:** `Active(context)` and `Set(context, bool)` are the only persistence interface; the API consumes `RequireOpen(context)` while the CLI invokes `Set`. UI consumes only `{ active: boolean }`.
