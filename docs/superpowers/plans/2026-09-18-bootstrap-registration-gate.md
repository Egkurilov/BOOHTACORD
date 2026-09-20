# Bootstrap Registration Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make public registration available only after the owner has atomically created the initial Administrator with the server-side bootstrap command.

**Architecture:** The registration repository will use an `INSERT … SELECT` sourced from the initialized singleton `bootstrap_state` row. A zero-row write maps to a domain error and then a bounded `503` response; bootstrap remains the only state writer and protected API routes retain their existing session middleware.

**Tech Stack:** Go 1.26, PostgreSQL/pgx, net/http, Vue 3/Vitest.

---

### Task 1: Specify the bootstrap gate

**Files:**
- Modify: `backend/internal/identity/register_user/service_test.go`
- Modify: `backend/internal/identity/register_user/postgres/repository_test.go`
- Modify: `backend/internal/identity/register_user/api/http_handler_test.go`

- [x] **Step 1: Add service propagation coverage**

```go
repository := &fakeRepository{err: ErrRegistrationUnavailable}
service := Service{accounts: repository, newID: func() (string, error) { return "account-1", nil }}
_, err := service.Register(context.Background(), Input{Login: "member", Password: "correct horse battery staple"})
if !errors.Is(err, ErrRegistrationUnavailable) {
	t.Fatalf("Register() error = %v", err)
}
```

- [x] **Step 2: Add repository zero-row coverage**

```go
repository := New(&fakeExecutor{tag: pgconn.NewCommandTag("INSERT 0 0")})
if err := repository.Create(context.Background(), registeruser.Account{}); !errors.Is(err, registeruser.ErrRegistrationUnavailable) {
	t.Fatalf("Create() error = %v", err)
}
```

Also assert the success SQL references `bootstrap_state`, requires `administrator_id IS NOT NULL`, and succeeds with `pgconn.NewCommandTag("INSERT 0 1")`.

- [x] **Step 3: Add HTTP mapping coverage**

```go
handler := NewHandler(registererFunc(func(context.Context, registeruser.Input) (registeruser.Account, error) {
	return registeruser.Account{}, registeruser.ErrRegistrationUnavailable
}))
recorder := httptest.NewRecorder()
handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", strings.NewReader(`{"login":"member","password":"correct horse battery staple"}`)))
if recorder.Code != http.StatusServiceUnavailable || !strings.Contains(recorder.Body.String(), `"REGISTRATION_NOT_READY"`) {
	t.Fatalf("status = %d, body = %s", recorder.Code, recorder.Body.String())
}
```

- [x] **Step 4: Run failing focused tests**

Run: `Push-Location backend; go test ./internal/identity/register_user/... -count=1; Pop-Location`

Expected: FAIL because the domain error and row-count contract do not exist.

### Task 2: Persist Member accounts only after initialization

**Files:**
- Modify: `backend/internal/identity/register_user/service.go`
- Modify: `backend/internal/identity/register_user/postgres/repository.go`
- Modify: `backend/internal/identity/register_user/postgres/pool_executor.go`

- [x] **Step 1: Define the detectable domain error**

```go
ErrRegistrationUnavailable = errors.New("registration is unavailable until administrator bootstrap")
```

Leave validation, Argon2id hashing, generated IDs, Member role assignment, and `%w` error wrapping in `Service.Register` intact.

- [x] **Step 2: Make the repository write conditional**

```sql
INSERT INTO users (id, login, display_name, role, password_hash)
SELECT $1, $2, $3, $4, $5
FROM bootstrap_state
WHERE singleton = TRUE AND administrator_id IS NOT NULL
```

Change the executor to return `(pgconn.CommandTag, error)`. Map `RowsAffected() == 0` to `ErrRegistrationUnavailable`; retain the `users_login_key` conflict mapping and wrapping of other database errors.

- [x] **Step 3: Return the native pgx command tag**

```go
func (executor PoolExecutor) Exec(ctx context.Context, statement string, arguments ...any) (pgconn.CommandTag, error) {
	return executor.pool.Exec(ctx, statement, arguments...)
}
```

- [x] **Step 4: Run focused tests**

Run: `Push-Location backend; go test ./internal/identity/register_user/... -count=1; Pop-Location`

Expected: PASS.

### Task 3: Expose a bounded public response

**Files:**
- Modify: `backend/internal/identity/register_user/api/http_handler.go`
- Modify: `frontend/src/identity/auth_client.spec.ts`

- [x] **Step 1: Map the unavailable error**

```go
if errors.Is(err, registeruser.ErrRegistrationUnavailable) {
	writeError(writer, request, http.StatusServiceUnavailable, "REGISTRATION_NOT_READY", "Регистрация откроется после начальной настройки сервера")
	return
}
```

Do not return account IDs, audit entries, or bootstrap state.

- [x] **Step 2: Add a client test for the bounded 503 message**

```ts
const request = vi.fn().mockResolvedValue(new Response(
  JSON.stringify({ error: { message: 'Регистрация откроется после начальной настройки сервера' } }),
  { status: 503 },
))
await expect(register({ login: 'member', password: 'correct horse battery staple' }, request))
  .rejects.toThrow('Регистрация откроется после начальной настройки сервера')
```

- [x] **Step 3: Run focused API and client tests**

Run: `Push-Location backend; go test ./internal/identity/register_user/api -count=1; Pop-Location; npm --prefix frontend exec vitest run src/identity/auth_client.spec.ts`

Expected: PASS.

### Task 4: Validate and deploy the leaf

**Files:**
- Modify: `evidence/deployment-remote-176108242211-002.json`

- [x] **Step 1: Run quality gates**

Run: `Push-Location backend; go test ./...; go vet ./...; Pop-Location; npm --prefix frontend test; npm --prefix frontend run build; .\scripts\verify-contracts.ps1`

Expected: all checks pass.

- [x] **Step 2: Build a unique pinned API image**

Copy only the changed API sources to `/opt/voice-platform`, set a non-`latest` `API_IMAGE`, build `api`, run `migrate`, then start only `api` with `--no-build`. The deployed web source is unchanged and already displays bounded API error messages.

- [x] **Step 3: Smoke the real bootstrap boundary without creating accounts**

Run: `curl --silent --output /dev/null --write-out '%{http_code}' --request POST --header 'Origin: https://v.bootybay.ru' --header 'content-type: application/json' --data '{"login":"member","password":"correct horse battery staple"}' https://v.bootybay.ru/api/v1/auth/register`

Expected: `503` while `bootstrap_state` is absent. Do not run bootstrap or submit owner credentials in a non-secret channel.
