# POC-01 Operator Runbook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the required Windows and Apple-Silicon macOS game-capture POC reproducible without treating a browser track, a mock, or a server health check as media evidence.

**Architecture:** Keep the existing short POC protocol as the normative summary, and add one operator-facing Markdown runbook beside it. The runbook has no application behaviour: it names the required owner/bootstrap state, same-origin administrator setup calls, physical-device procedure, failure classification, and evidence threshold.

**Tech Stack:** Markdown, existing HTTPS deployment, Vue browser client, Go API, LiveKit, Chrome Stable, physical Windows and Apple-Silicon macOS devices.

---

### Task 1: Add the POC-01 operator procedure

**Files:**
- Create: `docs/POC_01_OPERATOR_RUNBOOK.md`
- Read: `C:/Users/egkur/Downloads/TZ_Voice_Platform_v1.0.md` (REQ-SCREEN-02)
- Read: `docs/MEDIA_PROTOTYPE.md`
- Read: `docs/ADMIN_OPERATIONS.md`
- Read: `docs/API_AND_REALTIME.md`
- Read: `templates/evidence.json`

- [x] **Step 1: State the gate and its non-claims.**

Write that POC-01 is passed only by separate observed Windows and Apple-Silicon macOS runs showing moving real-game video, game sound, presenter voice, and no sustained digital loop. State that health checks, a LiveKit track, tab-only audio, and POC-02 profile measurements do not close the gate.

- [x] **Step 2: Provide secret-safe preflight and controlled topology setup.**

Document the existing owner-only bootstrap command by linking to `docs/ADMIN_OPERATIONS.md`, never placing a password in the document. Include an authenticated same-origin browser-console setup for one category and one `VOICE` channel using `POST /api/v1/admin/categories` and `POST /api/v1/admin/categories/{categoryID}/channels`; it must throw on a non-2xx result and contains no credentials.

- [x] **Step 3: Provide an observable, platform-by-platform test sequence.**

Specify headphones, a physical observer machine, a real game with recognisable sound, browser picker use, a moving-image observation, a separate game-audio observation, a presenter-voice observation, and a muted-observer loop check. Define `BLOCKED` for an OS/browser limitation and prohibit substituting a virtual cable, driver, desktop client, or tab-only audio.

- [x] **Step 4: Define records and pass/fail classification.**

Require one JSON evidence record per platform/run based on `templates/evidence.json`, timestamped non-secret artifacts, hardware/OS/Chrome/LiveKit details, and a named observer. Permit `PASS` only when every stated observation is witnessed; retain `FAIL`, `BLOCKED`, and `NOT_RUN` honestly otherwise.

### Task 2: Link the canonical media protocol

**Files:**
- Modify: `docs/MEDIA_PROTOTYPE.md`
- Create: `docs/POC_01_OPERATOR_RUNBOOK.md`

- [x] **Step 1: Add one navigational link after the POC-01 summary.**

Add a relative link to the operator runbook and make clear that it supplies execution detail rather than new product requirements.

### Task 3: Verify the documentation contract

**Files:**
- Test: `docs/POC_01_OPERATOR_RUNBOOK.md`
- Test: `docs/MEDIA_PROTOTYPE.md`

- [x] **Step 1: Parse the reusable evidence template.**

Run:

```powershell
Get-Content -Raw templates/evidence.json | ConvertFrom-Json | Out-Null
```

Expected: exit code `0`.

- [x] **Step 2: Check the runbook retains all mandatory guardrails.**

Run:

```powershell
$runbook = Get-Content -Raw docs/POC_01_OPERATOR_RUNBOOK.md
@('Apple-Silicon macOS', 'physical observer', 'game audio', 'sustained digital loop', 'BLOCKED', 'virtual cable') | ForEach-Object { if (-not $runbook.Contains($_)) { throw "Missing POC guardrail: $_" } }
```

Expected: exit code `0`.

- [x] **Step 3: Inspect the focused diff.**

Run:

```powershell
git diff --check
git status --short -- docs/MEDIA_PROTOTYPE.md docs/POC_01_OPERATOR_RUNBOOK.md docs/superpowers/plans/2026-09-18-poc-01-operator-runbook.md
```

Expected: no whitespace errors; only the three intended documentation paths are reported for this packet.

### Task 4: Record completed plan steps

**Files:**
- Modify: `docs/superpowers/plans/2026-09-18-poc-01-operator-runbook.md`

- [x] **Step 1: Mark every completed step after the documentation checks pass.**

Replace the task checkboxes above with `[x]` only after the new runbook, link, JSON parse, guardrail check, and focused diff check have all completed successfully.
