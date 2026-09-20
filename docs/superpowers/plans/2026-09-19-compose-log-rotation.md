# Compose Log Rotation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bound Docker JSON logs for each long-running Voice Platform service without changing chat or attachment retention.

**Architecture:** A Compose extension declares one `json-file` policy with a 10 MiB segment and three retained segments. Only the five long-running runtime services reference it; one-shot migrations and operator commands retain Docker defaults because they cannot grow indefinitely. A static verifier prevents removal or drift without needing a Docker daemon.

**Tech Stack:** Docker Compose YAML, PowerShell, repository-native static verification.

---

### Task 1: Add the failing Compose logging contract

**Files:**
- Create: `scripts/verify-compose-log-rotation.ps1`
- Test: `scripts/verify-compose-log-rotation.ps1`

- [x] **Step 1: Write the static verifier before the Compose policy exists.**

```powershell
$services = @('postgres', 'livekit', 'api', 'web', 'proxy')
foreach ($service in $services) {
    $block = [regex]::Match($compose, "(?ms)^  $service:\r?\n(?<body>.*?)(?=^  [a-z][a-z0-9-]*:\r?\n|^networks:)")
    if (-not $block.Success) { throw "Missing Compose service: $service" }
    if ($block.Groups['body'].Value -notmatch '(?m)^    logging: \*json-log-rotation$') {
        throw "Service $service must use json-log-rotation."
    }
}
```

- [x] **Step 2: Run the verifier and confirm it fails because no service references the policy.**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-compose-log-rotation.ps1`

Expected: failure naming the first missing `json-log-rotation` binding.

### Task 2: Define and bind the runtime logging policy

**Files:**
- Modify: `compose.yaml:1-172`
- Modify: `docs/ARCHITECTURE_AND_DATA.md:media admission and operations sections`
- Test: `scripts/verify-compose-log-rotation.ps1`

- [x] **Step 1: Define the reusable Compose extension at the document root.**

```yaml
x-json-log-rotation: &json-log-rotation
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

- [x] **Step 2: Bind each long-running service to that policy.**

```yaml
  api:
    logging: *json-log-rotation
```

Apply the same exact binding to `postgres`, `livekit`, `web`, and `proxy`; do not add it to one-shot migrations or operator profiles.

- [x] **Step 3: Document the boundary.**

```markdown
Compose rotates each runtime container's JSON log after 10 MiB and retains at most three files. This bounds operational logs only; it neither deletes PostgreSQL/chat/attachment data nor changes their retention policy.
```

- [x] **Step 4: Re-run the verifier.**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-compose-log-rotation.ps1`

Expected: `Compose log rotation contract: OK`.

### Task 3: Validate the production-safe rollout boundary

**Files:**
- Validate: `compose.yaml`
- Validate: `scripts/verify-compose-log-rotation.ps1`

- [x] **Step 1: Validate the static contract and the existing Compose image contract.**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-compose-log-rotation.ps1` and `powershell -ExecutionPolicy Bypass -File scripts/verify-compose-images.ps1`.

Expected: both commands pass when Docker Compose is available.

- [x] **Step 2: Defer production recreation while interactive media is active.**

The logging driver takes effect only when each service is recreated. Do not recreate API, LiveKit, web, proxy, or PostgreSQL until the owner confirms the active media session has ended. At rollout, inspect `docker compose config --quiet`, recreate only after that session, then check PostgreSQL health, `/api/v1/health`, and `/api/v1/maintenance`.

- [x] **Step 3: Preserve the dirty worktree.**

Run: `git status --short` and inspect only the three packet files. Do not stage or commit because this shared worktree contains user-owned changes.
