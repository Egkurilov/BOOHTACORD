# Explicit Compose Image Tags Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent the deployment from implicitly building or deploying a `latest` image by requiring explicit API and web image references in Compose.

**Architecture:** All Go process services share one `${API_IMAGE}` reference because they are alternate entrypoints of the same immutable build. The Vue service owns `${WEB_IMAGE}`. `.env.example` provides local `:dev` values only; production chooses immutable GHCR digest references through its private `.env`. A PowerShell validator reads the resolved Compose JSON and rejects absent, divergent or `latest` service images.

**Tech Stack:** Docker Compose, PowerShell 7, GitHub Actions.

---

### Task 1: Add the failing resolved-image validator

**Files:**
- Create: `scripts/verify-compose-images.ps1`
- Test: `scripts/verify-compose-images.ps1`

- [ ] **Step 1: Create a validator that requires the expected service image fields**

Use this resolved-image contract:

```powershell
$expected = @{
  api = 'voice-platform-api:dev'
  migrate = 'voice-platform-api:dev'
  'bootstrap-admin' = 'voice-platform-api:dev'
  'recover-admin' = 'voice-platform-api:dev'
  web = 'voice-platform-web:dev'
}
```

For every service, reject an absent image, an image ending in `:latest`, or a resolved value different from the expected local development image.

- [ ] **Step 2: Run it before the Compose change**

Run:

```powershell
./scripts/verify-compose-images.ps1
```

Expected: `FAIL` because the current Compose services have no explicit image references.

### Task 2: Make service images explicit and non-latest

**Files:**
- Modify: `compose.yaml`
- Modify: `.env.example`

- [ ] **Step 1: Add local development image defaults**

Append these exact non-secret values to `.env.example`:

```dotenv
API_IMAGE=voice-platform-api:dev
WEB_IMAGE=voice-platform-web:dev
```

- [ ] **Step 2: Bind all Go entrypoints to the single API image reference**

Add this to `api`, `migrate`, `bootstrap-admin` and `recover-admin`:

```yaml
image: ${API_IMAGE:?set API_IMAGE to a pinned image reference in .env}
```

- [ ] **Step 3: Bind the web service to its own image reference**

Add this to `web`:

```yaml
image: ${WEB_IMAGE:?set WEB_IMAGE to a pinned image reference in .env}
```

### Task 3: Enforce the invariant in CI and configuration validation

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `scripts/verify-compose-images.ps1`

- [ ] **Step 1: Resolve Compose with the safe example file in the validator**

Use:

```powershell
$resolved = docker compose --env-file .env.example -f compose.yaml config --format json
if ($LASTEXITCODE -ne 0) { throw 'Compose image configuration is invalid.' }
```

Then parse `$resolved | ConvertFrom-Json` and assert the five expected image strings.

- [ ] **Step 2: Add the validator to the existing CI contracts job**

Append `./scripts/verify-compose-images.ps1` after the existing Compose interpolation check. No registry login, image push or SSH deploy is added until repository and secret inputs are supplied.

- [ ] **Step 3: Run validation and inspect the scoped diff**

Run:

```powershell
./scripts/verify-compose-images.ps1
docker compose --env-file .env.example -f compose.yaml config --quiet
git diff --check -- .env.example compose.yaml scripts/verify-compose-images.ps1 .github/workflows/ci.yml
```

Expected: all commands pass and no resolved service refers to `latest`.
