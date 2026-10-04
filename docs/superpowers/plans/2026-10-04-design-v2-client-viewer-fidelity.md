# Design V2 client viewer fidelity implementation plan

> **For agentic workers:** Execute this bounded plan inline in the existing design worktree. The user has authorized implementation and verification; admin screens are last.

**Goal:** Align the real R04/R05 viewer with the supplied live HTML while preserving stream selection, audio controls and media cleanup.

**Architecture:** Keep ScreenViewer and its existing controller. Correct the viewer presentation CSS and use the shared identity palette for the stage avatar. Compare actual Vue renders against unchanged HTML under the same font/browser.

**Tech Stack:** Vue 3, TypeScript, Vite, Vitest, native Playwright probe.

## Operating brief

- Route: `small_direct`, T-030 viewer presentation; verification and branch sync are separate packets.
- Scope: `clients/web/src/voice/ScreenViewer.vue`, `screen_viewer_toolbar_layout.spec.ts`, `clients/web/src/design/design_v2_screen_viewer.css`, `design_v2_stream_diagnostics.css`.
- Baseline: master `7dd10d91`; 953 tests and production build previously passed. Fresh R04/R05 before captures include native interaction assertions and no browser errors.
- Ratchet: changed production files stay at or below 120 lines. No controller or media transport changes.
- Reference: immutable `screens/R04.html`, `screens/R05.html`; shared Inter font injected only in the capture page.
- Evidence folder: `C:/Users/egkur/.codex/visualizations/2026/10/03/01a1013e-bbb8-7052-94a3-88cb0dd3fc54/design-v2-viewer-fidelity-2026-10-04`.
- Stop condition: corrected geometry and visual diff improve on both viewports; nearest preservation tests and build pass; changes integrated with current master without losing concurrent work.
- Unresolved: canvas fixture resampling differs from the source image; report it separately from CSS fidelity. Admin polish is deferred by the user.

## Task 1 — regression expectations

- [x] Replace old CSS assertions for zero thumbnail padding and toolbar negative margins with measured values: thumbnail padding `1px 6px`, mobile preview height `50px`, desktop preview height `64px`, toolbar padding `4px` mobile / `4px 8px` desktop, icons `20px`, stroke `1.8`.
- [x] Run `npm test -- src/voice/screen_viewer_toolbar_layout.spec.ts` and save the expected failure in the evidence folder.

## Task 2 — presentation correction

- [x] Give cards block layout with explicit browser-equivalent padding; use full-width 28px captions, 6px gaps and 4px 8px caption padding. Keep native horizontal scrolling and selected borders.
- [x] Match the live badge with `padding: 2px 6px; font-size: 12px; line-height: 16px; color: #FF9AD5; background: #3D1831`.
- [x] Match stage label: radius 8px, translucent background, title weight 700; avatar uses `avatarBackground`/`avatarForeground` with `selectedStream.accountId ?? selectedStream.participantId` and retains weight 600.
- [x] Match toolbar 36px desktop / 44px mobile targets, 8px / 2px action gaps, 20px SVG icons. Remove compensating negative margins.
- [x] Capture R04 1440×900, R05 390×844 and narrow 320×844. Compare the 20 measured elements, inspect raw diff and exercise toolbar/stream interactions.

## Task 3 — verification and delivery

- [x] Run nearest viewer/controller/audio/fullscreen/overflow tests, then all web tests and `npm run build`; save real results.
- [ ] Save before/after raw diff and overlay for R04/R05 without shifting or changing reference pixels. Record remaining content/fixture differences explicitly.
- [ ] Inspect Git status, diff and changed file sizes; commit exact paths, fetch, merge current master, validate any changed web dependencies, push design branch and master.
- [ ] Update the current review pointer with the focused client result; leave overall goal active until all client/admin acceptance work is finished.

## Verified implementation additions

- Styled the native 0–200 audio range and retained its keyboard/store action contract; ScreenViewerAudioControl.vue is the fifth production file.
- Added clients/web/artifacts/design-v2/screen-viewer/verify-interactions.mjs: pin, statistics/focus, fullscreen, audio action, keyboard volume and selection preservation on actual components.
- Fresh result before integration: 955 tests, build and 1440/390/320 browser probes PASS; 20/20 reference element boxes match on R04 and R05.
