# GuildChat Profile and Administration API Implementation Plan

> **For agentic workers:** Execute the checked steps in order. This plan is separate from the later GitVerse deployment/review packet.

**Goal:** Add the authenticated profile, avatar, administrator member-list and audit-read capabilities needed by the GuildChat settings/admin screens, without weakening existing ACLs or exposing private chat data.

**Architecture:** Keep each operation in its own `backend/internal/identity/<operation>` leaf with API and PostgreSQL adapters. Profile operations derive the target only from the authenticated session; administrator list/audit operations require the existing administrator middleware. The Vue screens consume those APIs and remain in the central workspace. Publish exact HTTP schemas in OpenAPI and the mobile contract.

**Tech Stack:** Go 1.26, net/http, PostgreSQL/pgx, Vue 3/TypeScript/Vite, Vitest, existing private filesystem storage, OpenAPI.

---

### Task 1: Read and update the signed-in user's profile (T-010)

**Files:**
- Create: `backend/internal/identity/read_own_profile/{service.go,service_test.go}`
- Create: `backend/internal/identity/read_own_profile/api/http_handler.go`
- Create: `backend/internal/identity/read_own_profile/api/http_handler_test.go`
- Create: `backend/internal/identity/read_own_profile/postgres/repository.go`
- Create: `backend/internal/identity/read_own_profile/postgres/repository_test.go`
- Create: matching `update_own_profile` leaf files for PATCH validation and persistence
- Create: `backend/cmd/api/profile_routes.go`
- Modify: `backend/cmd/api/main.go`
- Modify: `contracts/openapi.yaml`
- Test: `scripts/verify-contracts.ps1`

- [x] Add service/API/repository tests first for an authenticated own-profile GET, display-name PATCH, malformed and unknown fields, unauthenticated requests, Unicode lengths 1 and 64 accepted/0 and 65 rejected, and a login field that is never mutable.
- [x] Confirm the focused Go tests fail because the profile leaves and routes do not exist.
- [x] Implement `GET /api/v1/me` and `PATCH /api/v1/me`; derive account ID only from `sessionapi.PrincipalFrom`, persist only `display_name`, preserve the immutable login, return structured errors with request ID, and leave Origin/CSRF enforcement to the existing global middleware.
- [x] Register the new operations through a thin route composition file so `main.go` remains under the file ratchet.
- [x] Run new leaf tests and full `go test ./...`, `go vet ./...`, and `scripts/verify-contracts.ps1`.

### Task 2: Change the current user's password (T-010)

**Files:**
- Create: `backend/internal/identity/change_own_password/{service.go,service_test.go,api/http_handler.go,api/http_handler_test.go,postgres/repository.go,postgres/repository_test.go}`
- Modify: `backend/cmd/api/profile_routes.go`, `backend/cmd/api/main.go`, `contracts/openapi.yaml`, and `contracts/mobile-client-contract.md`.

- [x] Test current-password verification, 12–128 Unicode-character validation, wrong-current-password rejection, bounded Argon2id verification/hash work, and preservation of the current authenticated session while revoking other sessions.
- [x] Implement `POST /api/v1/me/password` with a strict JSON body; never log, reflect, persist in client storage, or include either password in an error.
- [x] Run the leaf tests and full identity suite.

### Task 3: Upload and serve private profile avatars (T-010)

**Files:**
- Create one bounded `upload_own_avatar` leaf and one authenticated `read_member_avatar` leaf under `backend/internal/identity/`.
- Modify one migration to add a nullable avatar object key, `backend/cmd/api/profile_routes.go`, the profile response models and `/api/v1/members` projections.
- Create focused service, API, storage-adapter, and ACL tests; update `contracts/openapi.yaml` and `contracts/mobile-client-contract.md`.

- [x] First test JPEG/PNG input, a 2 MiB upload cap, a 4096-by-4096 dimension cap, invalid media bytes, replacement, unauthorized access, and authenticated member read access.
- [x] Normalize accepted images to PNG to remove embedded metadata; use the existing private filesystem root and a random object key, never a public object store, database volume, static web root, or log payload/filename/token.
- [x] Persist only an opaque avatar object key on the account; the authenticated read route checks the signed-in principal before returning bytes and safe content headers.
- [x] Run the avatar leaf tests and storage contract validators before implementing the Vue file picker.

### Task 4: List guild members and administrator accounts (T-010, T-014)

**Files:**
- Create: `backend/internal/identity/list_members/` leaf for safe member discovery and `backend/internal/identity/list_accounts/` leaf for administrator account state.
- Create: `backend/cmd/api/admin_account_list_routes.go`
- Modify: `backend/cmd/api/main.go`, `contracts/openapi.yaml`, and `contracts/mobile-client-contract.md`.

- [x] Test authenticated member listing with only public-profile fields; separately test administrator-only account listing with bounded pages, stable cursor ordering and blocked/role fields.
- [x] Implement `GET /api/v1/members` and `GET /api/v1/members/{memberID}` for authenticated one-guild profile discovery; implement `GET /api/v1/admin/accounts` for administrators only.
- [x] Exclude password/session/reset/media material and do not let administrators read message/DM content.
- [x] Run the leaf tests and contract validators.

### Task 5: Read a safe administrator audit feed (T-014)

**Files:**
- Create: `backend/internal/identity/list_audit_events/{service.go,service_test.go,api/http_handler.go,api/http_handler_test.go,postgres/repository.go,postgres/repository_test.go}`
- Add only the thin administrator route composition and route registration needed in `main.go`.
- Modify: `contracts/openapi.yaml` and `contracts/mobile-client-contract.md`.

- [x] Test cursor/limit validation, administrator-only route composition, actor/target summaries, and that arbitrary JSON metadata and message/DM bodies are never serialized.
- [x] Implement `GET /api/v1/admin/audit` over `audit_events`, selecting only event ID/type, actor and target IDs, and timestamp; never select or return `metadata`.
- [x] Run the audit leaf tests and contract validators.

### Task 6: Connect real profile and administrator screens

**Files:**
- Create: `frontend/src/identity/profile_client.ts` and its `.spec.ts`.
- Create: `frontend/src/identity/ProfileSettings.vue` and a focused component-contract test.
- Create: `frontend/src/workspace/AdminPanel.vue` and focused API/state tests.
- Modify: `WorkspaceApp.vue`, `WorkspaceMain.vue`, `WorkspaceUserFooter.vue`, `settings.css`, `design_system_contract.spec.ts`, and `style.css`.

- [x] Add API-client tests before implementing profile and administrator screens; assert same-origin cookies and exact endpoints, not secrets.
- [x] Render a data-backed editable display name, read-only login, avatar picker, separate current/new password form, loading/error/saved states, and an administrator members/channels/audit section switcher.
- [x] Bind role/block changes, voice kick, and one-time reset link actions only to existing/implemented server operations; keep reset links only in component memory and clear them on close.
- [x] Keep screens central at the documented widths, retain navigation/VoiceDock, hide the roster aside, and add responsive/table-scroll and accessible labels/focus states.
- [x] Run `npm test` and `npm run build`.

### Task 7: Synchronize API documentation and design TODO

**Files:**
- Modify: `contracts/openapi.yaml`, `contracts/mobile-client-contract.md`, `docs/design/GUILDCHAT_V1_TODO.md`, and `docs/design/GUILDCHAT_V1_STATUS.md`.

- [x] Validate every new request/response and authorization rule against handler tests and `scripts/verify-contracts.ps1`.
- [x] Close only those DS-T05/DS-T08 checks supported by code/tests; keep keyboard review and screenshot review open until evidence exists.
- [x] Run `scripts/verify-spec-traceability.ps1`; all 39 requirements remain referenced.

## Self-review and release boundary

- The product brief already requires a display name, optional avatar, current-password confirmation, two fixed roles, and administrator management; the owner has explicitly authorized exposing the missing API operations for the design screens.
- The design pack does not authorize adding email, extra roles, DM administration, public avatar storage, audit metadata disclosure, or fake production data.
- GitVerse Actions deployment and external Chrome visual acceptance remain a separate packet. A failed Chrome-control channel cannot be reported as a visual PASS.
