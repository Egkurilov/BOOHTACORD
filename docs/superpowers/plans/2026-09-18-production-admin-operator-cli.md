# Production Administrator Operator CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package the existing immutable administrator bootstrap and emergency recovery CLIs in the production image and expose them as private, explicit Compose one-shot services.

**Architecture:** Keep the existing Go commands and their stdin-only password boundary unchanged. The Docker build emits two additional binaries, and two Compose services are placed behind the `operator` profile on the private network. They never start with the application stack and receive only the same private database URL used by the migrator.

**Tech Stack:** Go 1.26, Docker multi-stage build, Docker Compose, PostgreSQL.

---

### Task 1: Add failing packaging assertions

**Files:**
- Modify: `backend/Dockerfile`
- Modify: `compose.yaml`
- Test: `backend/internal/identity/bootstrap_administrator/service_test.go`
- Test: `backend/internal/identity/recover_administrator/service_test.go`

- [ ] **Step 1: Run the existing administrator service tests before packaging**

Run:

```powershell
go test ./internal/identity/bootstrap_administrator ./internal/identity/recover_administrator -count=1
```

Expected: both typed services pass, proving packaging will not substitute their immutable-bootstrap and no-active-admin guards.

- [ ] **Step 2: Verify the current production image lacks the operator binary**

Run:

```powershell
docker compose --profile operator run --rm --no-deps bootstrap-admin --help
```

Expected: `no such service: bootstrap-admin` before the Compose change.

### Task 2: Package private one-shot services

**Files:**
- Modify: `backend/Dockerfile`
- Modify: `compose.yaml`

- [ ] **Step 1: Build both existing command packages into the final image**

Add these build and final-stage copy instructions:

```dockerfile
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/bootstrap-admin ./cmd/bootstrap_admin
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/recover-admin ./cmd/recover_admin

COPY --from=build /out/bootstrap-admin /bootstrap-admin
COPY --from=build /out/recover-admin /recover-admin
```

- [ ] **Step 2: Declare explicit operator-profile services**

Add `bootstrap-admin` and `recover-admin` services with these invariants:

```yaml
profiles: [operator]
build:
  context: ./backend
entrypoint: ["/bootstrap-admin"] # use /recover-admin for recovery
environment:
  DATABASE_URL: postgres://${POSTGRES_USER:-voice_platform}:${POSTGRES_PASSWORD:?set POSTGRES_PASSWORD in .env}@postgres:5432/${POSTGRES_DB:-voice_platform}?sslmode=disable
depends_on:
  postgres:
    condition: service_healthy
networks: [private]
```

No host ports, volumes, passwords, CLI password arguments or automatic dependencies are added.

- [ ] **Step 3: Validate the Compose graph and image command boundary**

Run:

```powershell
docker compose --profile operator config --quiet
docker compose --profile operator build bootstrap-admin recover-admin
docker compose --profile operator run --rm --no-deps bootstrap-admin
```

Expected: configuration and build succeed; the last command exits with the existing usage text because no login or stdin flag was supplied.

### Task 3: Document safe owner operation and deploy packaging

**Files:**
- Modify: `docs/ADMIN_OPERATIONS.md`

- [ ] **Step 1: Replace host Go commands with private Compose commands**

Document this shape without inserting a real password into shell history:

```bash
read -rsp 'Initial administrator password: ' BOOTSTRAP_PASSWORD; echo
printf '%s\n' "$BOOTSTRAP_PASSWORD" | sudo docker compose --profile operator run --rm -T bootstrap-admin --login owner --password-stdin
unset BOOTSTRAP_PASSWORD
```

Document the analogous `recover-admin` command and retain its no-active-administrator condition.

- [ ] **Step 2: Deploy only the rebuilt operator image**

Copy the three changed files, run `docker compose --profile operator build bootstrap-admin recover-admin`, and verify each command exposes only usage without database mutation when called with no arguments. Do not bootstrap an account without an owner-chosen login and password.

- [ ] **Step 3: Review scoped changes and tests**

Run:

```powershell
go test ./internal/identity/bootstrap_administrator ./internal/identity/recover_administrator -count=1
go test ./... && go vet ./...
git diff --check -- backend/Dockerfile compose.yaml docs/ADMIN_OPERATIONS.md
git status --short
```

Expected: all Go checks pass, no whitespace errors, and no unrelated dirty files are staged.
