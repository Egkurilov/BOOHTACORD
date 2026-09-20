# Direct-message candidate directory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide an authenticated, cursor-paginated directory of other active guild accounts that can be selected to open a one-to-one DM.

**Architecture:** The new chat leaf returns only another active account's ID and display name, never roles, login names or block metadata. Its PostgreSQL query excludes the caller and blocked accounts, orders by stable account ID, and fetches one extra row so the service derives `next_after` without loading the unbounded guild directory. The existing canonical `POST /direct-messages` remains the atomic authorization and pair-creation authority.

**Tech Stack:** Go, net/http, PostgreSQL/pgx, OpenAPI 3.1, Go tests.

---

### Task 1: Candidate list service and PostgreSQL projection

**Files:**
- Create: `backend/internal/chat/list_direct_message_candidates/service.go`
- Create: `backend/internal/chat/list_direct_message_candidates/service_test.go`
- Create: `backend/internal/chat/list_direct_message_candidates/postgres/repository.go`
- Create: `backend/internal/chat/list_direct_message_candidates/postgres/repository_test.go`
- Create: `backend/internal/chat/list_direct_message_candidates/postgres/pool_database.go`

- [x] **Step 1: Write failing service and repository tests**

```go
func TestListReturnsOneExtraRowAsCursorWithoutLeakingRoleOrBlockState(t *testing.T) {
  store := &fakeStore{candidates: []Candidate{{ID: candidateA, DisplayName: "Аня"}, {ID: candidateB, DisplayName: "Борис"}, {ID: candidateC, DisplayName: "Вика"}}}
  result, err := New(store).List(context.Background(), Input{ActorID: candidateActor, Limit: 2})
  if err != nil || len(result.Candidates) != 2 || result.NextAfter != candidateB || store.request != (Request{Input: Input{ActorID: candidateActor, Limit: 2}}) {
    t.Fatalf("result=%#v request=%#v error=%v", result, store.request, err)
  }
}

func TestRepositorySelectsOnlyOtherActiveAccountsInStablePages(t *testing.T) {
  database := &fakeDatabase{rows: &fakeRows{values: [][]any{{candidateB, "Борис"}}}}
  result, err := New(database).List(context.Background(), listdirectmessagecandidates.Request{Input: listdirectmessagecandidates.Input{ActorID: candidateActor, After: candidateA, Limit: 2}})
  if err != nil || len(result) != 1 || database.arguments[0] != candidateActor || database.arguments[1] != candidateA || database.arguments[2] != 2 {
    t.Fatalf("result=%#v arguments=%#v error=%v", result, database.arguments, err)
  }
  for _, fragment := range []string{"id <> $1::uuid", "blocked_at IS NULL", "($2::uuid IS NULL OR id > $2::uuid)", "ORDER BY id ASC", "LIMIT ($3::int + 1)"} {
    if !strings.Contains(database.statement, fragment) { t.Fatalf("missing %q", fragment) }
  }
  if strings.Contains(database.statement, "role") || strings.Contains(database.statement, "login") { t.Fatal("candidate projection leaked private fields") }
}
```

- [x] **Step 2: Run the focused Go tests to verify they fail**

Run: `go test ./internal/chat/list_direct_message_candidates/...` from `backend/`

Expected: FAIL because the candidate service package does not exist.

- [x] **Step 3: Implement validation, projection and cursor derivation**

```go
type Input struct { ActorID, After string; Limit int }
type Candidate struct { ID, DisplayName string }
type Result struct { Candidates []Candidate; NextAfter string }

func (service Service) List(ctx context.Context, input Input) (Result, error) {
  if !validUUID(input.ActorID) || (input.After != "" && !validUUID(input.After)) || input.Limit < 1 || input.Limit > 100 { return Result{}, ErrInvalidInput }
  candidates, err := service.store.List(ctx, Request{Input: input})
  if err != nil { return Result{}, fmt.Errorf("list direct message candidates: %w", err) }
  result := Result{Candidates: candidates}
  if len(result.Candidates) > input.Limit {
    result.NextAfter = result.Candidates[input.Limit-1].ID
    result.Candidates = result.Candidates[:input.Limit]
  }
  return result, nil
}
```

The repository query uses only `$1` actor UUID, nullable `$2` cursor UUID and `$3` requested limit. It selects `id::text, display_name` from `users`, excludes the actor and rows with `blocked_at`, orders by ID ascending and fetches `limit + 1` rows.

- [x] **Step 4: Run the focused Go tests to verify they pass**

Run: `go test ./internal/chat/list_direct_message_candidates/...` from `backend/`

Expected: PASS; invalid identifiers never reach persistence and extra-row pagination reports the final visible ID as `next_after`.

### Task 2: Protected HTTP route and declared contract

**Files:**
- Create: `backend/internal/chat/list_direct_message_candidates/api/http_handler.go`
- Create: `backend/internal/chat/list_direct_message_candidates/api/http_handler_test.go`
- Modify: `backend/cmd/api/chat_routes.go`
- Modify: `contracts/openapi.yaml`
- Modify: `docs/API_AND_REALTIME.md`
- Modify: `scripts/verify-contracts.ps1`

- [x] **Step 1: Write the failing HTTP handler test**

```go
func TestHandlerListsCandidatesForCurrentPrincipalWithBoundedCursor(t *testing.T) {
  var input listdirectmessagecandidates.Input
  handler := NewHandler(listerFunc(func(_ context.Context, value listdirectmessagecandidates.Input) (listdirectmessagecandidates.Result, error) {
    input = value
    return listdirectmessagecandidates.Result{Candidates: []listdirectmessagecandidates.Candidate{{ID: candidateB, DisplayName: "Борис"}}, NextAfter: candidateB}, nil
  }))
  request := httptest.NewRequest(http.MethodGet, "/api/v1/direct-message-candidates?after="+candidateA+"&limit=2", nil)
  request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: candidateActor, Role: "ADMINISTRATOR"}))
  recorder := httptest.NewRecorder()
  handler.ServeHTTP(recorder, request)
  if recorder.Code != http.StatusOK || input != (listdirectmessagecandidates.Input{ActorID: candidateActor, After: candidateA, Limit: 2}) || !strings.Contains(recorder.Body.String(), `"display_name":"Борис"`) || !strings.Contains(recorder.Body.String(), `"next_after":"`+candidateB+`"`) {
    t.Fatalf("status=%d input=%#v body=%q", recorder.Code, input, recorder.Body.String())
  }
}
```

- [x] **Step 2: Run the handler test to verify it fails**

Run: `go test ./internal/chat/list_direct_message_candidates/api` from `backend/`

Expected: FAIL because the HTTP handler module does not exist.

- [x] **Step 3: Implement authenticated route, OpenAPI and documentation**

```go
limit := 50
if rawLimit := request.URL.Query().Get("limit"); rawLimit != "" {
  parsed, err := strconv.Atoi(rawLimit)
  if err != nil { writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный размер списка участников"); return }
  limit = parsed
}
result, err := lister.List(request.Context(), listdirectmessagecandidates.Input{ActorID: principal.AccountID, After: request.URL.Query().Get("after"), Limit: limit})
```

Register `GET /api/v1/direct-message-candidates` behind `sessionapi.Require`. Add OpenAPI `DirectMessageCandidate` (`id`, `display_name`) and `DirectMessageCandidateList` (`candidates`, optional `next_after`) schemas, with `after` UUID and `limit` 1–100 query parameters. Document that the projection excludes the caller and blocked accounts and returns no role, login or block state; opening a selected candidate still calls the atomic canonical-pair command.

- [x] **Step 4: Verify route and contract checks**

Run: `go test ./internal/chat/list_direct_message_candidates/api` from `backend/`

Expected: PASS; an administrator principal has no role bypass and receives only the same caller-scoped candidate projection.

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-contracts.ps1`

Expected: PASS; the candidate endpoint and schemas are required by the contract verifier.

### Task 3: Regression validation and closeout

**Files:**
- Modify: `docs/superpowers/plans/2026-09-18-list-direct-message-candidates.md`

- [x] **Step 1: Run backend regression checks**

Run: `go test ./...` from `backend/`

Expected: PASS; all Go packages compile and test with the new route wiring.

Run: `go vet ./...` from `backend/`

Expected: PASS; no static Go diagnostics.

- [x] **Step 2: Verify traceability and whitespace**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1`

Expected: PASS; all requirements retain backlog links.

Run: `git diff --check`

Expected: exit 0 with no new whitespace errors.

- [x] **Step 3: Mark the completed checklist and evidence boundary**

Replace completed boxes with `[x]`. Report that static SQL and unit tests prove projection and route wiring, not a live PostgreSQL ACL integration test, browser participant selection, Windows/macOS media POC, capacity, deployment or release readiness.
