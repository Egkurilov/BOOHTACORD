# Design V2 settings header implementation plan

> Execute inline, task by task, under the user's continuing implementation authorization.

**Goal:** Match the real audio/profile settings headers to the handoff while preserving drawer and close/focus behavior.

**Architecture:** Move the duplicated settings header from WorkspaceMain into the shared workspace_header leaf. Move its shared CSS out of the administrator stylesheet into the same leaf. Keep existing labels, icon paths and emitted parent events.

**Tech Stack:** Vue 3, TypeScript, CSS, Vitest SSR, native Playwright probe.

## Operating brief

- workflow_class=small_direct; task_size=small; structure_mode=structure_no_rg; search_stage=exact_edges.
- Route: clients/web/src/shared/workspace_header, T-050 client UI; native edge WorkspaceMain.vue -> SettingsWorkspaceHeader.vue -> WorkspaceHeaderActions.vue.
- Doctrine: preserve first-pass product behavior, client-first/admin-last, no reference runtime substitution.
- Limits: target 100/hard 120 lines per source file; at most 8 production files and 8 direct tests for this leaf.
- Baseline: fc0ebe38; fresh R10/R11/R12 before/source captures in external design-v2-settings-header-2026-10-04.
- Confirmed: desktop empty navigation container adds 12px; title x differs by 8px, line-height 20 instead of 24; icon wrapper missing 24px box; stroke caps/joins differ.
- Native checks: focused Vitest, browser geometry/navigation/close on 1440/1024/390/320, full Web tests/build, raw PNG/HTML diff.
- Stop: shared header geometry and scoped pixels match HTML; existing real panel actions still pass. Full design goal stays active.
- No unresolved owner question. Requirements/contracts/backlog unchanged.

## 1. Regression and implementation

Files: new SettingsWorkspaceHeader.vue, settings_header.css and settings_header.spec.ts in the selected leaf; modify WorkspaceMain.vue, style.css, design_v2_admin_permissions.css.

- [x] Add SSR regression for audio/profile/admin title, close labels, expanded navigation and absence of member action; run and observe missing component failure.
- [x] Add browser assertions against captured source boxes before changing UI, preserve failing result.
- [x] Extract three duplicate header blocks, retaining `@toggle-navigation="emit('toggleNav')"` and `@close="emit('closePanel', panel)"` at existing parent branches.
- [x] Use a 24x24 icon wrapper containing the existing 20x20 SVG. Header title uses `font-size:16px; line-height:24px; font-weight:600`.
- [x] Hide `.settings-workspace-header .workspace-header-actions` at min-width 1024px; desktop/tablet padding 24/20px; mobile height 56px, padding 12px, gap 8px, 44px controls and hidden icon wrapper. Set SVG round caps/joins and header `flex:none`.
- [x] Move only shared header CSS from the admin stylesheet to `shared/workspace_header/settings_header.css`; retain admin panel-specific rules. Import at the original cascade position.
- [x] Run focused tests and browser checks; inspect actual and diff. Real profile PATCH, security tab, audio activation and close remain covered by native probe.

## 2. Evidence and delivery

- [x] Capture actual/source at R10/R11/R12 plus derived tablet/narrow states; compare without masks/alignment or changing reference files. Save hashes, metrics, raw diff, overlays, commands and limitations.
- [x] Run `npm test -- --reporter=dot`, `npm run build`, `git diff --check`; inspect changed file sizes.
- [ ] Commit exact source/test/plan paths, merge current remote master separately if changed, repeat checks for material Web changes, and fast-forward/push master.
- [ ] Update current review pointer and audit with tested source tree, delivery commit and observed CI result.

Validation complete at 1ba01e1d: 984 tests/build, 15 focused browser states and 29 fresh actuals pass. Delivery and user-requested stop are recorded in the external current review after workflow completion.
