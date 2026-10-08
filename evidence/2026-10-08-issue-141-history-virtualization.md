# Issue #141 history virtualization

Date: 2026-10-08
Base: `9b524569bb2b46b95afbb1f5040c32ceefda7214`
Implementation branch: `codex/web-history-virtualization-141`

## Repository behavior implemented

- Text history builds an ID-to-message index for reply previews, replacing repeated
  linear searches. Store replacement on edits, tombstones and channel changes
  refreshes the computed index.
- The chat timeline uses variable-height measured rows and renders only the viewport
  plus eight rows of overscan. Date dividers and the older-history control remain in
  the chronology.
- Reply navigation scrolls a loaded target into the virtual window. An actively
  focused or edited row remains mounted separately while the rest of the list stays
  bounded. Existing pagination, unread/latest behavior, attachment rendering,
  search/reply navigation, and edit/focus callbacks remain wired through the current
  components.
- The component regression renders a 10,000-message history and asserts fewer than
  40 message DOM rows while retaining the pagination control.

## Validation

| Check | Result |
| --- | --- |
| TDD baseline for history window and message index | Expected failure before implementation |
| `npx vitest run src/conversation` (from `clients/web`) | PASS — 69 files, 185 tests |
| `VITE_PUBLIC_ORIGIN=https://example.invalid npm run build` (from `clients/web`) | PASS — vue-tsc and Vite production build |
| `git diff --check` for implementation changes | PASS |
| Real-browser captures, viewport/scroll acceptance and heap measurements | NOT_RUN — no browser/device runtime acceptance performed in this worktree |

The production build reports the existing LiveKit mixed static/dynamic import warning
and an existing minified chunk over 500 kB. These warnings did not fail the build.

## Cache-eviction limitation

The in-memory message cache remains intact. The current text-history store exposes one
older-page cursor, while the transport supports `before`, `after` and `at` requests.
There is no store-level dual-cursor/window-anchor contract or defined refresh-and-merge
policy for evicted rows. Trimming cached history now could make backward pagination or
old-history anchor restoration unrecoverable. Safe bounded rendering is implemented;
safe cache eviction needs a separate store/API continuation design and regression
coverage before it can be enabled.
