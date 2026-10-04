# Audit Filter Layout Implementation Plan

> **For agentic workers:** Implement inline in this task; the user authorized the full design transformation.

**Goal:** Make UIR-07 audit events searchable by scope, date, type and actor while preserving their server meaning and pagination.

**Architecture:** Filter only loaded `AuditEvent` summaries by fields already parsed by the API client. The view retains the server pagination cursor, deduplicates appended pages by event ID, groups visible events by local day, and reveals only available event metadata.

**Tech Stack:** Vue 3, TypeScript, Vitest, Playwright, Design V2 CSS tokens.

---

### Task 1: Filtering contract

**Files:** `clients/web/src/admin/audit/audit_filter.ts`, `audit_filter.spec.ts`.

- [x] Write tests for admin/voice scope, inclusive date bounds, exact event type, actor ID, day grouping, and duplicate IDs across pages.
- [x] Run `npm test -- src/admin/audit/audit_filter.spec.ts` and observe failure before implementation.
- [x] Implement pure filtering/grouping and page append functions; run the focused test.

### Task 2: Responsive audit UI

**Files:** `AdminAuditSection.vue`, `AdminAuditFilters.vue`, `clients/web/src/design/design_v2_audit.css`, `clients/web/src/style.css`.

- [x] Add an SSR test for accessible filters and browser coverage of disclosure metadata.
- [x] Build scope, date, type and actor filters with a visible loaded-page notice; keep “Показать более ранние”.
- [x] Render compact day groups and per-event details from existing parsed fields only.
- [x] Run all web tests and `npm run build`.

### Task 3: Actual browser review

**Files:** `clients/web/artifacts/design-v2/admin-audit-probe.mjs`, external visual review report.

- [x] Capture desktop/mobile actual screens with synthetic API summaries and no message content.
- [x] Verify voice/admin/date/actor/type filters, pagination deduplication and page errors in Chromium.
- [x] Document structural diff and lack of a separate audit PNG golden, then inspect file sizes, commit and sync master.

**Preservation baseline:** The API client intentionally drops arbitrary `metadata`, including potentially sensitive content. Audit entries remain immutable; the UI does not claim before/after fields or exhaustive server-side search.
