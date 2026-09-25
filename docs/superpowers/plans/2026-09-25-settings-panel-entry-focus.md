# Settings panel entry focus

**Goal:** Keep keyboard focus inside the newly opened profile or audio panel when a mobile navigation drawer closes.

**Architecture:** Follow the admin panel's mounted-frame focus pattern: profile focuses its heading; audio focuses its first actionable control. Cancel scheduled focus when a panel unmounts.

**Tech stack:** Vue 3, TypeScript, Vitest, Vite, isolated local Go/PostgreSQL browser fixture.

- [x] Record failing browser focus states and add focused markup regression checks.
- [x] Add profile/audio entry focus while preserving drawer Escape restoration.
- [x] Run frontend tests and build; verify keyboard transitions at narrow and desktop widths on a fixed bundle.
- [x] Record evidence, update TODO/DONE, run traceability, inspect diff and file sizes.
