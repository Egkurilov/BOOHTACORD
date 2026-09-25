# Workspace panel mobile navigation

**Goal:** Let users reopen the navigation drawer from admin, audio, and profile panels at narrow viewport widths.

**Architecture:** Reuse the existing `WorkspaceHeaderActions` trigger in the three `WorkspaceMain` panel branches. Keep drawer state, focus trapping, and Escape behavior in the existing workspace controller.

**Tech stack:** Vue 3, TypeScript, Vitest, Vite, local Go/PostgreSQL browser fixture.

- [x] Record the narrow-viewport baseline and add a focused SSR regression test for the three panels.
- [x] Render the shared navigation trigger from each panel and keep desktop presentation unchanged.
- [x] Run the focused test, complete frontend test suite, and production build.
- [x] Verify admin, audio, and profile navigation at 320 and 883 CSS px in the isolated fixed-bundle browser; record focus and drawer state.
- [x] Update design/verification TODO and DONE with evidence, then inspect the diff and file sizes.
