# Client screen telemetry Implementation Plan

> **For agentic workers:** Inline execution in the current task. Steps use checkbox syntax for tracking.

**Goal:** Give administrators short-lived, anonymous sender/receiver screen-share indicators and export bounded aggregate counters through the private metrics endpoint.

**Architecture:** Authenticated clients submit a fixed-schema report without account, channel, track, SDP, ICE, or content fields. The Go process validates numbers, retains only the latest report for each fixed platform/direction pair for 60 seconds, and records bounded Prometheus counters/histograms. The admin tab reads that snapshot; the web viewer reports its receiver and presentation metrics automatically only while visible and watching a remote stream.

**Tech Stack:** Go 1.26, Prometheus client, Vue 3/TypeScript, Vitest.

---

### Task 1: Bounded recorder

**Files:** `backend/internal/observability/http_metrics/client_screen.go`, `backend/internal/observability/http_metrics/client_screen_test.go`, `backend/internal/observability/http_metrics/recorder.go`.

- [x] Test valid fixed-enum reports, invalid values, 60-second expiry, and absence of identifiers in Prometheus/admin output; the focused Go package failed before implementation.
- [x] Implement a mutex-protected latest-sample map with fixed keys, count and FPS/bitrate histograms, and an admin snapshot; the focused test passed.

### Task 2: Authenticated routes

**Files:** `backend/internal/observability/report_client_screen/api/http_handler.go`, its test, `backend/cmd/api/client_screen_routes.go`, `backend/cmd/api/main.go`.

- [x] Test 2 KiB strict JSON validation, authenticated POST, administrator-only GET, and response without IDs; the handler tests failed before implementation.
- [x] Wire routes through existing secure-session and Origin middleware; nearest API tests and `go vet` passed.

### Task 3: Web sender, receiver and admin view

**Files:** `frontend/src/voice/screen_client_reporter.ts`, its test, `frontend/src/voice/ScreenViewer.vue`, `frontend/src/voice/ScreenDiagnosticsPanel.vue`, `frontend/src/voice/screen_playback_quality.ts`, `frontend/src/workspace/AdminMediaDiagnostics.vue`, `frontend/src/workspace/AdminPanel.vue`.

- [x] Test client-report construction for waiting, stalled and playing states without identifying fields.
- [x] Report at a bounded cadence while a visible browser watches a remote stream or shares its own screen; show fresh anonymous platform/direction values in the admin tab.
- [x] Run focused tests, full frontend suite and TypeScript/Vite build.

### Task 4: Documentation and release

**Files:** `docs/ARCHITECTURE_AND_DATA.md`, `evidence/media/client-screen-telemetry-2026-09-26-001.json`.

- [x] Document client-reported limitations and privacy/retention, record source checks and physical-device status honestly.
- [ ] Inspect git status and file sizes; stage only reviewed files, commit, push to GitVerse master, then verify deployment health and admin visibility.
