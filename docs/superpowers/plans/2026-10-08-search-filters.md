# Unified Search Filters Implementation Plan

> **For agentic workers:** Execute inline in this packet. Keep the change inside the existing unified-search API and search UI; do not create a second search system.

**Goal:** Add author and attachment-presence filters to existing unified message search while preserving its server ACL, deleted-message exclusion, mixed-source cursor ordering, and filter state when the user returns from a result.

**Architecture:** Extend the existing `/api/v1/search/messages` query with an optional author UUID and optional attachment-presence boolean. Apply both predicates inside the current authorized PostgreSQL query before cursor pagination. Carry the same criteria on every page and keep the two UI filters in an in-memory Pinia store, which is discarded by the existing authenticated-state reset. Date filtering is deliberately excluded until the product owner defines timezone and interval-boundary semantics.

**Tech Stack:** Go, PostgreSQL, OpenAPI, Vue 3, TypeScript, Pinia, Vitest.

---

### Task 1: Specify and implement the backend filter contract

**Files:**
- Modify: `contracts/openapi.yaml` at `/api/v1/search/messages`
- Modify: `backend/internal/chat/search_messages/api/http_handler.go`
- Test: `backend/internal/chat/search_messages/api/http_handler_test.go`
- Modify: `backend/internal/chat/search_messages/service.go`
- Test: `backend/internal/chat/search_messages/service_test.go`
- Modify: `backend/internal/chat/search_messages/postgres/statements.go`
- Modify: `backend/internal/chat/search_messages/postgres/repository.go`
- Test: `backend/internal/chat/search_messages/postgres/repository_test.go`

- [ ] **Step 1: Add failing handler and service tests**

Cover valid `author_id` and `has_attachment=true|false`, duplicate/malformed parameters, non-UUID authors, and invalid boolean values. Confirm the service passes filters to the store and continues rejecting mutually exclusive channel/DM scope, bad cursors, and invalid limits. Run from `backend/`:

```powershell
go test ./internal/chat/search_messages/api ./internal/chat/search_messages
```

Expected before implementation: new valid-filter cases fail because the handler/service currently discard or reject the fields.

- [ ] **Step 2: Add repository regression coverage**

Assert the query keeps the existing live TEXT/non-deleted predicates, own-DM participant predicate, `(created_at, id, kind)` ordering, and cursor tuple comparison, while applying author and attached-file `EXISTS` predicates before pagination. Confirm absent `has_attachment` remains unfiltered and both boolean values reach the query distinctly. Run:

```powershell
go test ./internal/chat/search_messages/postgres
```

- [ ] **Step 3: Implement the API and SQL filters**

Parse `author_id` as one UUID and `has_attachment` as exactly `true` or `false`; represent absent attachment filter separately from false. Forward filters through the service and repository. For channel messages use `message_attachments`; for DM messages use `direct_message_attachments`; count only links to attachments in `ATTACHED` state. Keep the existing deleted predicates and channel/DM authorization conditions unchanged. Update OpenAPI with these parameter definitions and privacy/behavior descriptions.

- [ ] **Step 4: Run backend tests and contract validation**

```powershell
cd backend
go test ./internal/chat/search_messages/...
cd ..
powershell -ExecutionPolicy Bypass -File tools/verify/contracts/verify-contracts.ps1
```

Expected: focused search packages pass and OpenAPI contract validation reports no errors.

### Task 2: Expose filters and retain them across navigation

**Files:**
- Create: `clients/web/src/search/filters/state.ts`
- Test: `clients/web/src/search/filters/state.spec.ts`
- Create: `clients/web/src/search/filters/SearchFilters.vue`
- Modify: `clients/web/src/search/search_messages_client.ts`
- Test: `clients/web/src/search/search_messages_client.spec.ts`
- Modify: `clients/web/src/search/SearchPanel.vue`

- [ ] **Step 1: Add failing client and filter-state tests**

Assert the client serializes author and attachment filters on both initial and cursor requests. Assert the filter store keeps values when a search panel is reconstructed and has empty defaults in a new authenticated Pinia state. Run from `clients/web/`:

```powershell
npm run test -- src/search/search_messages_client.spec.ts src/search/filters/state.spec.ts
```

Expected before implementation: tests fail because the input type, query serialization, and filter store do not exist.

- [ ] **Step 2: Implement client filter serialization**

Add optional `authorId` and tri-state attachment input to `SearchMessagesInput`; serialize only selected values. Keep `before` and the exact same filters together for each page. Preserve same-origin credentials and current result validation.

- [ ] **Step 3: Add session-bound filter state and compact controls**

Create a Pinia store for `authorId` and attachment state (`any`, `with`, `without`). `SearchFilters.vue` uses the existing authenticated member directory and exposes a bounded “load more” action when another member page exists. `SearchPanel.vue` reads the store, includes both filters in each search request, and resets results/cursor when a filter changes. Existing `clearAuthenticatedState` disposes Pinia stores at logout, so filter state does not cross authenticated sessions.

- [ ] **Step 4: Run focused frontend tests and typecheck/build**

```powershell
npm run test -- src/search/search_messages_client.spec.ts src/search/filters/state.spec.ts
npm run build
```

Expected: focused tests and the existing Vue/TypeScript production build pass.

### Acceptance boundary

The approved `REQ-SEARCH-01` and current OpenAPI explicitly retain non-deleted messages, active TEXT channels, and only the caller's own DM pairs. The product spec does not define a local timezone or inclusive/exclusive date-range boundary. This packet leaves date behavior unchanged and reports that decision as remaining work. QA-04 browser acceptance, local-time boundary checks, SQL-plan/index acceptance, and deployment acceptance are not run or claimed here.
