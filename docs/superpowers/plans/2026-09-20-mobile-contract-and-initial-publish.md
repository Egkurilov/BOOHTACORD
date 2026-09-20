# Mobile Contract and Initial Publish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish the current source tree safely and add a stable mobile-client integration contract derived from the canonical HTTP and realtime contracts.

**Architecture:** `contracts/openapi.yaml` remains the machine-readable HTTP authority and `contracts/realtime.schema.json` remains the realtime authority. `contracts/mobile-client-contract.md` gives mobile developers the exact transport, authentication, lifecycle, retry, and ownership rules without creating a drifting copy of endpoint schemas.

**Tech Stack:** OpenAPI 3.1 JSON document, JSON Schema, Go HTTP API, WebSocket, LiveKit, PowerShell contract validator, Git.

---

### Task 1: Add a mobile integration contract with a validator

**Files:**
- Create: `contracts/mobile-client-contract.md`
- Modify: `scripts/verify-contracts.ps1`
- Test: `scripts/verify-contracts.ps1`

- [x] **Step 1: Add a failing presence-and-canonical-source check.**

```powershell
$mobileContractPath = Join-Path $PSScriptRoot '..\contracts\mobile-client-contract.md'
if (-not (Test-Path -LiteralPath $mobileContractPath)) {
    throw "Mobile client contract is unavailable: $mobileContractPath"
}
```

- [x] **Step 2: Run the verifier before creating the document.**

Run: `& .\scripts\verify-contracts.ps1`

Expected: FAIL with `Mobile client contract is unavailable`.

- [x] **Step 3: Write the mobile document from canonical contracts only.**

```markdown
# Mobile Client Backend Contract

Canonical schemas: `openapi.yaml` and `realtime.schema.json`.

## Authentication

Use the server-issued opaque session cookie in the platform cookie store; do not persist a password, reset token, media token, or websocket URL token.
```

Cover REST endpoint groups, ID/cursor/revision retry rules, websocket event kinds, Voice Lease → LiveKit Credential lifecycle, and ACL/error handling. State unsupported mobile capabilities explicitly rather than inventing them.

- [x] **Step 4: Make the verifier assert both canonical references and mobile lifecycle headings.**

```powershell
$mobileContract = Get-Content -Raw -LiteralPath $mobileContractPath
foreach ($requiredText in @('openapi.yaml', 'realtime.schema.json', 'Voice lease', 'LiveKit credential')) {
    if ($mobileContract -notmatch [regex]::Escape($requiredText)) {
        throw "Mobile client contract is missing required section: $requiredText"
    }
}
```

- [x] **Step 5: Run the verifier after the document exists.**

Run: `& .\scripts\verify-contracts.ps1`

Expected: `Contracts OK.`

### Task 2: Create the first safe repository commit

**Files:**
- Modify: `.gitignore`
- Commit: all reviewed source, contracts, docs, tests, and scripts in the working tree

- [x] **Step 1: Exclude generated Windows executables and retain explicit environment protections.**

```gitignore
.env
*.exe
node_modules/
dist/
```

Do not add `backend/api.exe`, `backend/recover_last_admin_access.exe`, private `.env`, volumes, uploaded attachments, temporary archives, or production credentials.

- [x] **Step 2: Inspect every staged and untracked candidate by path and size.**

Run: `git status --short`; `git diff --cached --name-only`; `git ls-files --others --exclude-standard`.

Expected: only source, documentation, schemas, tests, build configuration, and automation are candidates.

- [x] **Step 3: Stage reviewed candidates and create the initial commit.**

```powershell
git add -- <reviewed paths>
git commit -m "feat: bootstrap voice platform and mobile contracts"
```

Expected: a first commit on `codex/voice-platform-foundation` with no generated executables or secrets.

### Task 3: Push when a remote is configured

**Files:**
- No source changes

- [x] **Step 1: Inspect the configured remote.**

Run: `git remote -v`

Expected: a fetch/push URL for the user-owned remote.

- [ ] **Step 2: Push the committed branch.**

```powershell
git push --set-upstream origin codex/voice-platform-foundation
```

Expected: the remote reports the new branch and commit.

**Blocker:** At plan creation the repository has no configured remote, so no destination exists for a push. A remote URL or permission to choose/create one is required.

## Self-review

- **Coverage:** Covers the requested standalone mobile contract, validation, safe full-tree commit, and remote push.
- **Preservation:** Does not alter API semantics, create a mobile app, add a second auth mechanism, or expose credentials.
- **Limit:** The mobile document is an integration guide, not a duplicate OpenAPI schema; generated SDKs must use the canonical OpenAPI file.
