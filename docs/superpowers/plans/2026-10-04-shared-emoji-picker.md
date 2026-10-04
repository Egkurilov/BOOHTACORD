# Shared Emoji Picker Implementation Plan

> **For agentic workers:** Implement inline in this task; the user authorized the Design V2 chat transformation.

**Goal:** Complete UIR-04 emoji selection in channel and DM composers while preserving the quick row, draft caret and no-send behavior.

**Architecture:** A shared `EmojiPicker` owns quick choices, search, recent choices, keyboard navigation and a compact popover. Both existing composers retain their own drafts and pass a selected emoji through a pure UTF-16 textarea-range insertion function; selection returns focus and caret to the source textarea.

**Tech Stack:** Vue 3, TypeScript, Vitest, Playwright, Design V2 CSS tokens.

---

### Task 1: Insertion and catalog

**Files:** `clients/web/src/conversation/emoji_catalog.ts`, `emoji_insert.ts`, `emoji_picker.spec.ts`.

- [x] Write a failing test for insertion in the middle of text with a skin-tone modifier and untouched surrounding content.
- [x] Test search labels and recent ordering; run the focused test to observe failure.
- [x] Implement a searchable Unicode catalog and pure insertion/recent functions.

### Task 2: Shared picker

**Files:** `EmojiPicker.vue`, `TextConversation.vue`, `../direct_message/DirectMessageConversation.vue`, `clients/web/src/design/design_v2_emoji.css`, `clients/web/src/style.css`, `composer_v2_icons.spec.ts`.

- [x] Replace duplicated six-emoji strips with the shared quick row and «Все emoji» panel.
- [x] Insert at textarea selection; restore focus/caret, including mobile plus-menu activation.
- [x] Add keyboard arrows/Escape and 44px mobile cells; update source contract tests.
- [x] Run focused/full Web tests and TypeScript/Vite build.

### Task 3: Actual review

**Files:** browser probe in `clients/web/artifacts/design-v2`, external visual report.

- [x] Capture channel/DM actual open picker on desktop/mobile and verify search/recent/keyboard/caret/no send.
- [x] Recheck R01–R03 and R28 closed-picker appearance against unchanged PNG references.
- [x] Record diff and remaining limits, inspect file sizes and status, commit and sync master.

**Preservation baseline:** Sending remains in `useScopedSend`; picker selection changes only the draft. No new network access or message send is introduced.
