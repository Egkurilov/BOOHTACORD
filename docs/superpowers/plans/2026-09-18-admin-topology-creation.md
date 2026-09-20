# Administrator Topology Creation Implementation Plan

> **For agentic workers:** Execute the plan task by task, updating its checkboxes only after the corresponding focused verification passes.

**Goal:** Let a session-confirmed administrator create a category and a text or voice channel through the existing administrator-only API, so the owner can prepare POC topology after the secure owner-login handoff.

**Architecture:** The identity session gate retains the server-returned role and passes it to the mounted workspace. A narrowly scoped channel client serializes typed, same-origin creation requests and parses only the documented responses. The workspace conditionally mounts an administrator control surface for the server-confirmed `ADMINISTRATOR` role; it refreshes the existing topology store after each successful mutation. The API continues to authorize every mutation independently of this UI affordance.

**Tech Stack:** Vue 3, TypeScript, Pinia, Vitest, existing Go administrator channel endpoints.

---

### Task 1: Pin typed administrator API behaviour with focused tests

**Files:**
- Create: `frontend/src/channel/admin_topology_client.spec.ts`
- Create: `frontend/src/channel/admin_topology_client.ts`

- [x] **Step 1: Test category creation request and response parsing.**

Assert that `createCategory` posts JSON `{ name }` to `/api/v1/admin/categories` with `credentials: 'same-origin'` and parses the documented `Category` response.

- [x] **Step 2: Test text/voice channel creation request and invalid responses.**

Assert that `createChannel` URL-encodes the category ID, posts only `{ name, kind }`, parses the documented `Channel` response, and rejects a malformed response rather than rendering it.

- [x] **Step 3: Implement the bounded client.**

Reuse the existing `ChannelKind` and return typed category/channel data. Reject unexpected non-2xx responses with a bounded status error and never log request bodies.

- [x] **Step 4: Run the focused client test.**

Run: `npm test -- src/channel/admin_topology_client.spec.ts`

Expected: both endpoint contracts and malformed-response behavior pass.

### Task 2: Expose the administrator-only creation controls

**Files:**
- Create: `frontend/src/channel/AdminTopologyControls.vue`
- Modify: `frontend/src/App.vue`
- Modify: `frontend/src/workspace/WorkspaceApp.vue`
- Modify: `frontend/src/style.css`

- [x] **Step 1: Preserve the authenticated role in the root session gate.**

Store the `CurrentSession` result, render the workspace only when it is non-null, and pass its role as a typed prop. A guest still mounts no workspace requests and a session error remains retryable.

- [x] **Step 2: Implement an accessible, bounded creation form.**

The component accepts the current categories, creates a named category, and creates a named immutable `TEXT` or `VOICE` channel in a selected category. It disables duplicate submission, provides an `aria-live` completion state and bounded alert failures, and emits `changed` after success. It does not implement client-only authorization, renaming, moving, reordering, archive, deletion, or voice-admission operations.

- [x] **Step 3: Mount controls only for the server-confirmed administrator role.**

Pass the existing topology categories to the controls when `role === 'ADMINISTRATOR'`. On `changed`, refresh the topology store so navigation reflects server state. Members receive no control surface, and the API remains the authority for all mutation attempts.

- [x] **Step 4: Add focused responsive visual styles.**

Use component-specific classes that match the existing keyboard-visible controls and sidebar palette without modifying media behavior or ACL.

### Task 3: Add the deferred owner handoff and validate this leaf

**Files:**
- Modify: `TODO.md`
- Modify: this plan

- [x] **Step 1: Add a safe deferred POC owner-login task.**

Add a P0 TODO item requiring the owner to paste the bootstrap password from their secure local clipboard into their own browser, verify the session, create the POC category and voice channel, and retain the Windows/macOS physical-observer POC gate. Do not include any credential in the TODO, evidence, source, or chat.

- [x] **Step 2: Run native frontend and traceability checks.**

Run:

```powershell
Push-Location frontend
npm test
npm run build
Pop-Location
scripts/verify-spec-traceability.ps1
git diff --check
```

Expected: Vitest, TypeScript/Vite build, spec traceability and diff check pass.

- [x] **Step 3: Inspect scoped changes without staging.**

Run `git status --short` and inspect changed file sizes. Do not deploy or perform an owner login: both require a secure owner-side handoff and are retained as the POC follow-up.

**Coverage review:** This leaf covers the existing create-category and create-channel UI gap within T-014/T-020. It does not claim that owner authentication, POC topology, LiveKit media, Windows/macOS game-audio capture, or POC-01 passed.
