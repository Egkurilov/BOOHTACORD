# Design V2 compact voice strip implementation plan

> **For agentic workers:** Execute inline in the existing design worktree; the user authorized implementation and verification.

**Goal:** Match the compact mobile voice strip to live HTML R02/R05 while retaining voice actions and the expanded navigation drawer.

**Architecture:** Keep the real VoiceDock component and event contract. Scope presentation overrides to the compact sidebar state; use the existing browser fixture for preservation tests.

**Tech Stack:** Vue, CSS, Vitest, Playwright.

## Operating brief

- Workflow `small_direct`, task small; leaf T-022/VoiceDock compact presentation. Branch sync and verification remain separate packets.
- Baseline `ca3798e6`, clean tree. Before captures R02/R05 and same-font HTML are in `design-v2-compact-voice-2026-10-04` under the thread visualization directory.
- Exact files: `clients/web/src/design/design_v2_voice_dock.css`; `clients/web/artifacts/design-v2/voice-dock/probe.mjs`. Read-only entry: `clients/web/src/voice/VoiceDock.vue` and native responsive stylesheet imports.
- Preserve microphone/deafen/PTT/reconnect/leave/share events, measured quality and drawer behavior. No media controller changes.
- Limits: each changed file ≤120 lines, one presentation trigger family.
- Stop: seven measured elements match HTML at 390 px, responsive/component regressions pass at 320/390/1440; client source/PNG diff improves; integrate with master.

## Steps

- [x] Add browser regression for compact padding 12px, title 12px/400/#78E6A0, subtitle 11px, mic x=`width-108`, leave x=`width-56`; run `node artifacts/design-v2/voice-dock/probe.mjs <evidence>/red` and verify failure.
- [x] Add scoped rules under `@media(max-width:1023px)`: compact dock padding `4px 12px`, action gap `8px`, title size/weight/color, subtitle size, unmuted mic secondary color.
- [x] Repeat component browser probe and R02/R05 actuals, compare unchanged source/goldens without masks; check open drawer and desktop retain prior layout.
- [x] Run nearest dock tests and production build; inspect Git status, diff and line counts; commit exact paths and integrate current master.
- [x] Record remaining client work separately; admin remains last.
