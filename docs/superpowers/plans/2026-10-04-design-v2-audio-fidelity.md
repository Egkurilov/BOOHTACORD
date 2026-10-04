# Design V2 audio settings fidelity implementation plan

> **For agentic workers:** Execute inline in the existing design worktree. Client screens have priority over administration.

**Goal:** Align the real R10/R11 device and activation panels with HTML and keep dynamic PTT/device feedback contained.

**Architecture:** Keep AudioSettings stores and AudioDeviceCheck lifecycle. Correct measured CSS and allow intrinsic card growth for dynamic controls. Keep processing diagnostics accessible below the processing card so the reference card retains its shape.

**Tech Stack:** Vue/TypeScript, CSS, Vitest, native Playwright fixtures.

## Operating brief

- `small_direct`, medium; T-022/audio settings presentation. Baseline `e9870cfc` includes completed compact voice strip.
- Exact production files: `clients/web/src/voice/AudioSettings.vue`, `clients/web/src/design/design_v2_audio_presentation.css`.
- Tests: `src/voice/audio_settings_v2_layout.spec.ts`, `artifacts/design-v2/audio/verify-interactions.mjs` plus existing audio preference/store/device tests.
- Inputs: unchanged R10/R11 live HTML, same-font browser measurements and PNG. Artifacts: thread `design-v2-audio-fidelity-2026-10-04` folder.
- Preserve device IDs, permission/error feedback, PTT assignment, microphone meter/track cleanup, processing settings and experimental release gates. Real level zero and real gain preference are not replaced with decorative source values.
- Limits: production files ≤120 lines; two production files in this packet.
- Stop: measured spacing improves, dynamic feedback stays inside cards, source/runtime tests pass; record full diff including semantic differences.

## Steps

- [x] Add native/browser regressions: PTT assignment must fit within activation card, microphone feedback must fit device card; switch boxes have no UA margin and inactive color uses control-border token. Run before implementation and save failure.
- [x] Use description font 13px, action gap 12px desktop, mobile check margin-top -20px, explicit segmented padding 4px 12px and gap 8px.
- [x] Change device/activation fixed heights to equivalent min-heights with intrinsic growth. Move preserved diagnostics after the processing card; processing heading margin 4px, last row 64px without divider, switch margin 0 and control-border background.
- [x] Repeat 1440/390/320 captures and real UI checks; verify PTT selection, meter remains real, processing settings and diagnostics survive. Compare original unmodified HTML/PNG.
- [x] Run focused tests, complete web tests and build; merge current master, revalidate changed dependencies and publish exact changes with evidence.

## Verified outcomes

- 21/21 measured boxes match on R10/R11. The initial browser test reproduced PTT overflow; intrinsic card heights fixed PTT and device-feedback containment.
- Mobile PTT is 44px tall; the 40×24 noise glyph has a 44×44 hit area verified by a click outside its painted bounds.
- Full web suite: 298 files / 958 tests PASS; build PASS. Existing JS chunk warning remains.
