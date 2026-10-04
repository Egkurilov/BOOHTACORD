# Participant Volume Implementation Plan

> **For agentic workers:** Execute inline, task by task. Owner already authorized implementation and code-only merging; runtime checks/builds are deferred to the grouped run.

**Goal:** Restore 0–200% participant volume by local account, remote account and deployment origin on every client.

**Architecture:** Versioned account documents retain microphone/screen levels independently. Gain changes immediately; 250ms persistence coalesces writes, flushes at interaction end/leave/logout, and never writes into a later account. Reset clears the account document and disables legacy fallback. Browser storage is inherently origin-scoped; native storage gets an explicit normalized origin.

**Tech Stack:** Vue/Pinia/TypeScript, Flutter/Dart/SharedPreferences, authenticated OTLP relay in Go.

Operating brief: split_first; T-022 (T-006/T-020 dependencies); native leaf routes
participant_volume, volume_preferences, volumes and volume_preference sanitizer.
Preserve LiveKit media ownership, deafen, independent screen gain and account ACL.
Target 100/hard 120 new source lines and 8/hard 16 source/test files per leaf.

### 1. Focused persistence tests first

Checkboxes track authored scenarios; execution remains NOT_RUN.

- [x] Web tests: rapid `setParticipant(remote, 175)` updates cache immediately; storage writes only after 250ms or `flush()`. New object/rebind reads 175; account switch reads 100. Corrupt/unavailable storage restores 100 with fallback status.
- [x] Native tests: explicit origin scopes; saved 0/100/200 and screen values survive reopen; one write for rapid changes; reset affects inactive peers and excludes a different origin/account.
- [x] Rejoin/SID/rename test: cards change from old SID to new SID with identical account ID; gain remains saved. Logout/rebind keeps persistent data.

### 2. Persistence implementation

Create Web participant_volume/{document,preferences,controls,view,types,reporting}.ts and forward
voice_volume_preferences.ts. Create native volume_preferences/{model,state,storage,write}
with the public service export. Add `flush()`, `reset()`, status and close/unbind.
Version 2 document key is account-scoped (native also origin-scoped). Preserve
trusted browser v1 values until explicit reset. Native v1 originless data stays
untouched and is not silently assigned to an unproven deployment.

### 3. Lifecycle and immediate application

Update exact volume controls/change/apply, admission prepare and account cleanup
edges. Capture old storage keys before async work. Flush on leave/logout; reload
for rejoin; suppress stale account/session completions. Storage fallback keeps
call controls usable, with a dedicated nonblocking volume warning.

### 4. UI and reset

Name Web sliders with participant name and `aria-valuetext`. Extract native card
volume menu into widgets/participant_volume; reuse an accessible slider in the
profile and card, with immediate local feedback and onChangeEnd flush.
Audio settings expose `Сбросить настройки аудио` with copy explaining participant/
screen levels return to 100% on this device. Works before joining as well.

### 5. Telemetry and evidence

Emit only `volume_preference_apply=success|fallback|error` and bounded platform.
Add a sanitizer and privacy tests; never send percentages or participant IDs.
Document storage/lifecycle/reset contract and Web/Windows/Android/iOS physical
repeat-join protocol. Mark deferred gates NOT_RUN; do not claim audible PASS.

### 6. Handoff

Inspect status, exact candidate sizes and source diff; sync current master.
Commit/push/merge with [skip ci]. Keep physical acceptance open.

Grouped native commands (not run now): Web `npm test -- participant_volume voice_volume`;
Flutter `flutter test test/voice_volume_preferences_test.dart test/participant_volume_test.dart test/participant_volume_lifecycle_test.dart test/participant_volume_ui_test.dart`;
Go `go test ./internal/observability/ingest_client_traces/...`. Add device evidence
for actual audible gain, reconnect/new SID and logout/login before closing #107.
