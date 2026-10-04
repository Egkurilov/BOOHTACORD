# Design V2 navigation controls plan

Execute inline; `small_direct`, T-050 (T-020/T-022/T-040), leaf: guild navigation controls.

**Goal:** Match guild header, search launcher and section tabs to R01/R14 HTML while retaining actual navigation, permissions and voice ownership.

**Architecture:** `WorkspaceApp` composes `SearchLauncher` and `WorkspaceSidebarTabs`; add scoped presentation CSS and replace the decorative guild-chevron glyph with the source SVG. Preserve all emits/stores/permission guards.

**Files:** `clients/web/src/workspace/WorkspaceApp.vue`, `clients/web/src/design/design_v2_navigation_controls.css`, `clients/web/src/style.css`. Native checks: `workspace_panel_navigation.spec.ts`, `workspace_drawer_focus.spec.ts`, search shortcut/focus tests; actual Chromium controls and screenshots.

- [x] Measure immutable R01/R14 HTML with local Inter and current real components. Record failing properties/geometry before edits.
- [x] Header: 15/700 title, 20 px line box, caption 12/16, border, grow column, 36 px desktop SVG-chevron wrapper; preserve mobile close control.
- [x] Search: canvas fill, muted text, 8 px radius, 10 px inset; Ctrl K uses inherited Inter 11/16, surface fill, subtle border and 4 px radius.
- [x] Tabs: desktop 40 px container with 4 px padding, 32 px selected visual and raised fill; retain existing downstream channel-tree position.
- [x] Mobile search/tab hit rectangles reach 44 px using expanded buttons and inset painted backgrounds; visible content remains aligned with HTML.
- [x] Measure again; verify switching channels/DM tabs, search open/close, guild admin guard, mobile pointer hit areas and connected voice state. Capture R01/R14, compare immutable PNGs and keep derived-state differences explicit.
- [x] Run closest native tests and production build; inspect files/line counts, record evidence, commit the bounded packet.

Stop when measured header/search/tab visuals match source, mobile hit areas are verified, and navigation/voice state is preserved. Full Design V2 completion remains open. Production files stay below 120 lines.
