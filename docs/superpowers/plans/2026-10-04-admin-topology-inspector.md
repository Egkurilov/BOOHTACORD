# Admin Topology Inspector Implementation Plan

> **For agentic workers:** Implement inline in this task. The user has already authorized implementation and verification.

**Goal:** Replace the disconnected administrator topology forms with a shared category/channel tree and a selected-object inspector while retaining the existing API editors.

**Architecture:** The tree emits category or channel IDs. `AdminTopologyControls` owns one selection and renders the existing category, create, rename, move, order, archive, and close editors for that object. The editors retain their revision checks, confirmations, and standalone selectors for existing callers.

**Tech Stack:** Vue 3, TypeScript, Vitest, Playwright, CSS tokens.

---

### Task 1: Tree selection

**Files:** `clients/web/src/channel/AdminTopologyTree.vue`, `clients/web/src/channel/admin_topology_tree.spec.ts`.

- [x] Write a failing SSR test with two categories and three channels that checks ordered rows, text/voice marks, and the selected ID.
- [x] Run `npm test -- src/channel/admin_topology_tree.spec.ts` in `clients/web` and verify the missing component failure.
- [x] Add an accessible tree with button rows, stable ID events, and token-based states.
- [x] Run the focused test and commit after the whole packet passes.

### Task 2: Selected-object inspector

**Files:** `clients/web/src/channel/AdminTopologyControls.vue`, `AdminChannelCreate.vue`, `AdminCategoryControls.vue`, `AdminChannelRename.vue`, `AdminChannelMove.vue`, `AdminChannelOrder.vue`, `AdminTextArchive.vue`, `AdminVoiceClose.vue`, and `clients/web/src/design/design_v2_admin_topology.css`.

- [x] Add a test that a selected channel binds each editor to its ID and omits duplicate object selectors; keep existing standalone editor tests.
- [x] Run the focused test to confirm it fails before changing implementation.
- [x] Move channel creation to its own form, wire the tree selection and inspector, and allow controlled selection in the existing editors.
- [x] Style desktop columns and a mobile stacked layout using current Design V2 tokens.
- [x] Run channel tests, full web tests, and `npm run build`.

### Task 3: Actual visual and behavior review

**Files:** `artifacts/design-v2/dom-probe.mjs`, existing design audit Markdown in the visual artifact directory.

- [x] Capture the real admin channels screen at desktop and mobile with the fixture topology; record actual screenshots and browser metadata.
- [x] Verify keyboard reorder, rename/move revision behavior, and close confirmation without changing the PNG references. Creation and archive retain their existing native unit coverage.
- [x] Append structural diff findings and remaining gaps to the design audit, inspect the candidate file sizes and Git status, then commit and sync master.

**Preservation baseline:** Current editors mutate by ID with revision guards. Archive clears selected text; voice close retains the server/SFU lifecycle. No media state changes occur in the new selection layer.

**Stop condition:** This packet ends when the tree/inspector works in the real app and native checks pass. The larger Design V2 goal remains active until all visual states and review items are closed.
