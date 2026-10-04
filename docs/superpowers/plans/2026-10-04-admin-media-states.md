# Admin Media States Implementation Plan

> **For agentic workers:** Implement inline in this task; the user authorized the full Design V2 transformation.

**Goal:** Make UIR-12 diagnostics distinguish missing, stale, populated and failed reports without implying a measured media capability.

**Architecture:** Keep the existing bounded anonymous API parser. A pure state selector classifies samples by their real timestamps and retains the last observed report time. The Vue view renders short empty steps, comparable sender/receiver stages, a freshness summary, and a disclosure of client-report limits.

**Tech Stack:** Vue 3, TypeScript, Vitest, Playwright, Design V2 CSS tokens.

---

### Task 1: Honest data states

**Files:** `clients/web/src/admin/media/admin_media_state.ts`, `admin_media_state.spec.ts`.

- [x] Add failing tests for empty, fresh, stale and error states, plus the count of fresh reports.
- [x] Run the focused test to observe the missing implementation.
- [x] Implement the pure state selector using the server timestamps and a 60-second freshness window.

### Task 2: Screen layout

**Files:** `AdminMediaDiagnostics.vue`, `AdminMediaSampleCard.vue`, `clients/web/src/design/design_v2_admin_media.css`, `clients/web/src/style.css`.

- [x] Show the last successful refresh time and fresh count when known.
- [x] Replace the long empty paragraph with three steps; move measurement caveats into a native details disclosure.
- [x] Show each platform/direction and available values in sending, receiving, decoding and display stages, with unavailable stages labelled as such.
- [x] Run nearest tests, full web tests and TypeScript/Vite build.

### Task 3: Actual-state review

**Files:** `clients/web/artifacts/design-v2/admin-media-probe.mjs`, external visual review report.

- [x] Capture desktop/mobile actual empty, populated, stale and error states with fixture responses; inspect layout.
- [x] Confirm no names or IDs appear and no capture begins automatically.
- [x] Record structural diff and absent separate golden, inspect file sizes and status, commit and sync master.

**Preservation baseline:** A sample remains client-reported, bounded to 16 anonymous entries and 60 seconds; no participant identity, video content or capability claim is added.
