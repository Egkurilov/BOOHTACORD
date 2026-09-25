# Search drawer layering

**Goal:** Make the modal global-search drawer usable by pointer and keyboard at mobile and tablet widths.

**Architecture:** Preserve the existing drawer/scrim interaction and fix the later search CSS rule that places the drawer beneath its scrim. Test the effective z-index across the active CSS import order and responsive breakpoints.

**Tech stack:** Vue 3, Vite CSS, Vitest/PostCSS, isolated Go/PostgreSQL browser fixture.

- [x] Record the failing browser hit test at 320, 883 and 1024 CSS px; add a focused CSS-cascade regression test.
- [x] Raise the search drawer above its scrim without changing persistent desktop aside layout.
- [x] Run focused and full frontend tests and TypeScript/Vite build; verify clicks, focus, Escape and visual layout in the browser.
- [x] Record evidence, update TODO/DONE, run traceability, and inspect exact diff and file sizes.
