# Design V2 search feedback implementation plan

Execute inline in the existing design worktree; this is a continuation of the full Design V2 plan.

**Goal:** Make search idle, loading, empty and failure feedback visible and accessible, as required by implementation spec §6.6.

**Architecture:** Keep `SearchPanel.vue` request sequencing, filters, pagination and response parsing. Add a presentation class to its existing live region; override the inherited member-paragraph rule for feedback only. The successful R13 result layout stays unchanged.

**Tech stack:** Vue, CSS, Playwright Chromium, existing Vitest search tests.

## Operating brief

- Class `small_direct`; leaf `search/feedback`; backlog T-050, dependencies T-020/T-022/T-040.
- Exact production files: `clients/web/src/search/SearchPanel.vue`, `clients/web/src/design/design_v2_search_presentation.css`.
- Test files: `clients/web/artifacts/design-v2/search-feedback/fixture.mjs`, `probe.mjs`.
- Preserve Enter submission, current scope, message opening, unmount/stale-response guard, and live status announcements.
- Ratchet: each changed production/probe file below 120 lines; no API or media changes.
- Stop: desktop/mobile transitions pass, R13 successful screenshot unchanged, closest search tests and build pass; record actuals/diff externally. Full 1:1 remains a separate open goal.

## Steps

- [x] Add an isolated API fixture with held search responses. Probe the real App at 1440×900 and 390×844 through idle → pending → empty → error → retry/results, then close/reopen during a pending request.
- [x] Run `node artifacts/design-v2/search-feedback/probe.mjs <output-dir>` before edits; retain screenshots and JSON even on assertion failures.
- [x] Bind `search-status--visible` when `loading || (!error && (!searched || !messages.length))`. Use `role="status"` on the existing polite live region.
- [x] Give visible feedback static layout, 14/20 type, 16 px vertical margins, secondary color and natural wrapping. Error alerts use danger color. Horizontal margins follow the existing form: desktop 20 px, mobile 16 px.
- [x] Re-run the same probe. Verify search input/scope disabled while pending, alerts associated with query, retry successful, and old responses ignored after unmount.
- [x] Run `npm test -- src/search` and `npm run build`; capture standard R13 with the existing fixture and compare to the pre-change actual and immutable reference.
- [x] Inspect changed-file sizes and diff, record evidence and limitations, commit this bounded fix.
