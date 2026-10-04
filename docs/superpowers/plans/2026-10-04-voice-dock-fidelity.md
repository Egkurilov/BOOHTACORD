# Voice dock and account presentation

Route: `small_direct`; T-050; leaves `VoiceDock` presentation and `WorkspaceUserFooter` presentation, implemented sequentially.
Sources: immutable R01/R14 HTML + PNG. Preserve connected/transitional states, measured quality, PTT/deafen controls, screen lifecycle and footer navigation.
Edges: `VoiceDock.vue`, `WorkspaceUserFooter.vue`, scoped presentation CSS в†’ `style.css`.
Ratchet: changed production files <120 lines; no store/transport changes.

- [x] Capture before screenshots and computed source/actual geometry on desktop/mobile.
- [x] Write focused icon/presentation regressions, then align dock header, controls and source SVG.
- [x] Align account text/avatar, status decoration and settings icon, preserving both existing actions.
- [x] Verify real footer navigation and component event/disabled-state behavior; native nearest tests and build.
- [x] Capture after + raw diff/overlay against immutable references; record remaining dynamic differences.
- [x] Inspect status/file sizes, commit and integrate into master.

Stop: bounded components agree with source geometry/styles, interaction checks pass, evidence records limits; full design goal remains active until remaining differences are resolved.

