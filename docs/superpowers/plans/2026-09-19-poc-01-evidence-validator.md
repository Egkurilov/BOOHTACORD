# POC-01 Evidence Validator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Reject a claimed POC-01 pass unless two non-secret records prove the required Windows and Apple-Silicon macOS observations.

**Architecture:** A PowerShell verifier accepts two explicit JSON paths instead of discovering evidence files. It validates fixed, low-cardinality facts and emits only generic failures; it never reads media, logs, credentials, or message content. The reusable template and operator runbook define the exact fields that a human fills after physical runs.

**Tech Stack:** PowerShell 5.1+, JSON evidence records, existing POC-01 operator runbook.

---

### Task 1: Specify the failure-safe contract

**Files:**
- Create: `scripts/verify-poc-01-evidence.test.ps1`
- Test: `scripts/verify-poc-01-evidence.test.ps1`

- [x] **Step 1: Create valid isolated Windows and macOS records.**

Write a test helper that serializes this observation shape into `$TestDrive` without a real person, media, or secret:

```powershell
@{ moving_game_video = $true; game_audio = $true; presenter_voice = $true; no_sustained_digital_loop = $true; moving_video_observation_seconds = 10 }
```

Use `presenter_os = 'Windows'`, `presenter_architecture = 'amd64'` for the Windows file and `presenter_os = 'macOS'`, `presenter_architecture = 'arm64'` for the macOS file. Give each run distinct non-empty presenter and observer machine labels, a UTC `executed_at`, `PASS`, a capture source, and one object artifact with `storage = 'secured-outside-repository'`.

- [x] **Step 2: Assert the red state.**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-poc-01-evidence.test.ps1
```

Expected: failure because `scripts/verify-poc-01-evidence.ps1` does not exist.

- [x] **Step 3: Cover the mandatory negative cases.**

Call the future verifier with the valid pair and require exit `0`. Mutate only the macOS architecture to `x64` and require a nonzero exit. Mutate the Windows status to `BLOCKED` and require a nonzero exit. Put `secret-token` in an otherwise invalid test record and require that captured output does not contain it.

### Task 2: Implement the explicit two-record verifier

**Files:**
- Create: `scripts/verify-poc-01-evidence.ps1`
- Test: `scripts/verify-poc-01-evidence.test.ps1`

- [x] **Step 1: Load only the caller-supplied JSON records.**

Define mandatory parameters:

```powershell
param(
    [Parameter(Mandatory = $true)][string]$WindowsEvidence,
    [Parameter(Mandatory = $true)][string]$MacEvidence
)
```

Resolve each path with `Test-Path -LiteralPath`, parse with `Get-Content -Raw | ConvertFrom-Json`, and throw only `Windows POC evidence is incomplete.` or `macOS POC evidence is incomplete.` on any invalid value. Do not enumerate `evidence/` or print record content.

- [x] **Step 2: Require every observed pass fact.**

For both records, require `kind = 'poc-01'`, `status = 'PASS'`, a parseable timestamp, non-empty and distinct presenter/observer machines, non-empty observer, Chrome version, LiveKit digest, game, capture source, and a nonempty artifacts array. Require the four true observation booleans and `moving_video_observation_seconds -ge 10`.

For Windows require `presenter_os = 'Windows'`. For macOS require `presenter_os = 'macOS'` and `presenter_architecture = 'arm64'`. Require the Windows and macOS presenter machines to differ.

- [x] **Step 3: Emit one safe success line.**

After all checks, output exactly:

```powershell
Write-Output 'POC-01 evidence gate: PASS'
```

- [x] **Step 4: Run the focused test.**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-poc-01-evidence.test.ps1
```

Expected: `POC-01 evidence verifier tests: OK`.

### Task 3: Document the record schema and validate it

**Files:**
- Modify: `templates/evidence.json`
- Modify: `docs/POC_01_OPERATOR_RUNBOOK.md`
- Modify: `docs/superpowers/plans/2026-09-19-poc-01-evidence-validator.md`

- [x] **Step 1: Extend only the reusable template.**

Add `presenter_architecture: null` under `environment` and an `observations` object with the four nullable booleans plus `moving_video_observation_seconds: null`. Do not edit existing historical evidence.

- [x] **Step 2: Add the post-run command to the operator runbook.**

Document `arm64` as the required Apple-Silicon value and add this command with placeholders that cannot be copied as real paths:

```bash
powershell -ExecutionPolicy Bypass -File scripts/verify-poc-01-evidence.ps1 -WindowsEvidence <windows-record> -MacEvidence <macos-arm64-record>
```

State that a successful script result validates record completeness only and does not replace the physical observer's judgement.

- [x] **Step 3: Run repository checks.**

Run `powershell -ExecutionPolicy Bypass -File scripts/verify-poc-01-evidence.test.ps1`, parse `templates/evidence.json`, run `scripts/verify-spec-traceability.ps1`, and inspect `git diff --check` for the five packet files.

- [x] **Step 4: Mark these steps complete only after green checks.**

Replace this plan's unchecked task boxes with `[x]` after its test, JSON parse, traceability verifier, and focused diff check succeed.

## Self-review

- **Coverage:** The two-record gate requires Windows, Apple-Silicon macOS, game video/audio, presenter voice, loop observation, separate observers, timing, and protected artifacts.
- **Safety:** Failures carry no JSON values or filesystem enumerations; the validator never handles media, credentials, tokens, messages, or attachment content.
- **Non-claim:** Passing this verifier does not itself prove that a real human performed the observations.
