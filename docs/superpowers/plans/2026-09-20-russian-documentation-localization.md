# Russian Documentation Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Перевести поддерживаемую человекочитаемую документацию проекта на русский без изменения API, требований, команд, идентификаторов и машинных форматов.

**Architecture:** Локализуются только поддерживаемые Markdown-материалы продукта, эксплуатации, ADR и мастер-спецификации. OpenAPI/JSON Schema, evidence JSON, исходный код, `AGENTS.md`, `START_AGENT.md`, сторонние зависимости и исторические планы остаются без перевода: они являются машинными контрактами, рабочими инструкциями или архивом.

**Tech Stack:** Markdown, PowerShell, Git, проектные contract/traceability validators.

---

### Task 1: Зафиксировать границы и перевести пользовательские контракты

**Files:**
- Modify: `README.md`, `backlog/TASKS.md`, `contracts/mobile-client-contract.md`, `evidence/README.md`
- Preserve: `contracts/openapi.yaml`, `contracts/realtime.schema.json`, `backlog/tasks.yaml`, all `evidence/*.json`
- Test: locale sentinel check and `scripts/verify-contracts.ps1`

- [x] **Step 1: Зафиксировать исключения и проверить исходный английский заголовок mobile-контракта.**

```powershell
(Get-Content -Raw contracts/mobile-client-contract.md) -match '^# Mobile Client Backend Contract'
```

Expected: `True`; this is the red localization precondition.

- [x] **Step 2: Перевести prose, headings and tables, сохранив literal identifiers.**

Keep verbatim: paths, HTTP methods/statuses, JSON keys, UUID names, enum values, command blocks, filenames, `Voice lease`, `LiveKit credential`, `client_message_id`, `event_id`, `Retry-After`, and the canonical source filenames.

- [x] **Step 3: Проверить русский заголовок и канонические mobile sentinel strings.**

```powershell
$mobile = Get-Content -Raw contracts/mobile-client-contract.md
if ($mobile -notmatch '^# Контракт backend для мобильного клиента') { throw 'Russian heading is missing.' }
foreach ($literal in @('openapi.yaml', 'realtime.schema.json', 'Voice lease', 'LiveKit credential')) {
  if ($mobile -notmatch [regex]::Escape($literal)) { throw "Missing literal: $literal" }
}
& .\scripts\verify-contracts.ps1
```

Expected: Russian heading is present and `Contracts OK.`

### Task 2: Перевести поддерживаемые product и operator docs

**Files:**
- Modify: `docs/ACCEPTANCE.md`, `docs/ADMIN_OPERATIONS.md`, `docs/MEDIA_PROTOTYPE.md`, `docs/RESEARCH_NOTES.md`, `docs/UI_SPEC.md`
- Modify: `docs/adr/ADR-001-password-hashing.md`, `docs/adr/ADR-002-opaque-session-tokens.md`, `docs/adr/ADR-003-auth-rate-limits.md`, `docs/adr/ADR-004-administrator-bootstrap-and-recovery.md`, `docs/adr/ADR-005-self-hosted-livekit-revocation.md`
- Preserve: all code blocks, endpoint paths, environment-variable names, images, semantic versions, enum/error identifiers and requirement IDs
- Reviewed unchanged: `docs/API_AND_REALTIME.md`, `docs/ARCHITECTURE_AND_DATA.md`, `docs/POC_01_OPERATOR_RUNBOOK.md`; they already carry Russian product terms where appropriate, while their formal protocol vocabulary stays literal to avoid translation drift.
- Test: Markdown link/path validation and `scripts/verify-spec-traceability.ps1`

- [x] **Step 1: Локализовать narrative prose and table headings without translating protocol literals.**

For example, `GET /api/v1/health`, `POST`, `MEMBER`, `ADMINISTRATOR`, `ACTIVE_VOICE_LEASE`, `POC-01`, `PASS`, `BLOCKED`, `$BOOTSTRAP_PASSWORD`, and `/opt/voice-platform` stay byte-for-byte unchanged.

- [x] **Step 2: Проверить, что ключевые документационные ссылки и runnable commands сохранены.**

```powershell
foreach ($path in @('docs/API_AND_REALTIME.md','docs/ARCHITECTURE_AND_DATA.md','docs/ADMIN_OPERATIONS.md')) {
  if (-not (Test-Path -LiteralPath $path)) { throw "Missing localized document: $path" }
}
if ((Get-Content -Raw docs/ADMIN_OPERATIONS.md) -notmatch 'bootstrap-admin') { throw 'Bootstrap command changed.' }
& .\scripts\verify-spec-traceability.ps1
```

Expected: all files exist, bootstrap command literal remains, and traceability reports 39 requirements.

### Task 3: Локализовать мастер-спецификацию и зафиксировать изменение

**Files:**
- Modify: `docs/specs/spec-voice-platform/SPEC.md`, `architecture.md`, `functional-contract.md`, `delivery-and-verification.md`, `.memlog.md`
- Preserve: `CAP-1`…`CAP-10`, frontmatter companion paths, OpenAPI/realtime names and evidence filenames/statuses
- Test: master-spec structural check

- [x] **Step 1: Проверить master-spec companions и сохранить его русское ядро, BMad-поля и machine-facing literals.**

The spec remains a consolidated contract; translated text may not turn `PASS_RUNTIME`, `BLOCKED`, `NOT_RUN`, runtime smoke, or code presence into product acceptance.

- [x] **Step 2: Append a localization event to `.memlog.md`; do not rewrite prior decision records.**

```markdown
2026-09-20 | event | Russian localization completed for maintained human-readable documentation; protocol literals and machine contracts were preserved.
```

- [x] **Step 3: Validate stable capability IDs and companion paths.**

```powershell
$spec = Get-Content -Raw docs/specs/spec-voice-platform/SPEC.md
if (@([regex]::Matches($spec, '(?m)^- id: CAP-\d+$')).Count -ne 10) { throw 'Capability IDs changed.' }
foreach ($path in @('architecture.md','functional-contract.md','delivery-and-verification.md')) {
  if (-not (Test-Path -LiteralPath (Join-Path 'docs/specs/spec-voice-platform' $path))) { throw "Missing companion: $path" }
}
```

Expected: ten stable capability IDs and all local companions exist.

### Task 4: Review and publish the translation

**Files:**
- Commit: reviewed localization files and this plan only
- Preserve: no machine schemas, source code, secrets, evidence JSON, dependencies or historical plans are staged
- Test: `git diff --check`, contract and traceability validators

- [x] **Step 1: Inspect changed paths and file sizes before staging.**

```powershell
git status --short
git diff --stat
```

Expected: only the named documentation scope and the localization plan are changed.

- [ ] **Step 2: Stage explicit reviewed paths, validate and commit.**

```powershell
git add -- <reviewed documentation paths>
git diff --cached --check
git commit -m "docs: localize maintained documentation to Russian"
```

- [ ] **Step 3: Push the reviewed commit through the configured SSH remote.**

```powershell
$env:GIT_SSH_COMMAND='ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new'
git push origin HEAD:master
```

## Self-review

- **Coverage:** The scope includes the mobile contract specifically named by the user, current product/operator docs, ADRs, master-spec and concise navigation/evidence docs.
- **Preservation:** API schema files, requirements IDs, code blocks, endpoint paths, error/status identifiers, evidence payloads and historical plans are excluded from translation.
- **Validation:** Contract, traceability, structural and Git whitespace checks prove localisation did not alter machine-facing contracts.
