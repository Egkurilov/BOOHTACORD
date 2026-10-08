# Voice timeout admin controls implementation plan

Goal: let administrators read, set and lift ADR023 voice timeouts in the existing
member directory, without changing account roles, TEXT/DM access or media state.
Architecture: one child leaf admin/voice_timeout owns strict wire parsing,
request lifecycle and a small Vue control. Existing member menus mount it.
Tech stack: Vue3, TypeScript, existing secure-cookie tracedFetch, Vitest/Playwright.
Route: small_direct; target100/hard120 lines, leaf target8/hard16 files/tests.
Baseline: current member directory 16 focused tests PASS; preserve save/reset.

## Exact implementation and checks

- [x] Add client.spec.ts before client.ts: assert selected encoded account path,
  `credentials:'same-origin'`, PUT body `{expires_at,reason_code}`, DELETE, GET;
  malformed state rejects, sanitized status fallback and no private error echo.
- [x] Add state.spec.ts before state.ts: injected deferred requests prove disposal
  and account epoch safety; only loaded state permits mutation; failure replaces
  success, manual clear retains server pending state and never calls media.
- [x] Add client.ts with typed State/Reason and bounded code-specific errors.
  Parse `active`, ISO expiry/reason only when active, nonnegative revoked_leases
  and boolean revocation_pending. Reject unexpected active state rather than
  inventing completion. Use GET/PUT/DELETE ADR023 routes only.
- [x] Add state.ts using Vue refs, AbortController and disposed generation.
  `load`, `set(minutes,reason)`, `clear` and `dispose` form one request lifecycle.
  Set accepts 5/15/60/240/1440 minutes and bounded four enum reasons.
- [x] Add VoiceTimeoutControl.vue: lazy explicit status read; uniquely labelled
  duration/reason fields; confirmation submit; lift/refresh; status and alert;
  pending text describes queued removal, expiry requires explicit manual Join.
- [x] Modify members/AdminMembersSection.vue by import and child bindings in
  desktop action menu and mobile editor. Never fetch every member at mount.
- [x] Run `npm test -- src/admin/voice_timeout src/admin/members
  src/identity/admin_directory_client.spec.ts`: red first, then PASS.
- [x] Add tests/voice_timeout fixture/config/browser.spec.ts mounting the real
  member directory. At390/1440 exercise actual lazy GET, reason/expiry PUT,
  pending→clear state, keyboard controls, 403 failure, and no media calls.
- [x] Run actual Chromium `npx playwright test -c
  tests/voice_timeout/playwright.config.ts`, then full `npm test` and
  `npm run build`. Record mocks versus physical SFU/device limits explicitly.
- [x] Update IMP44 and evidence/voice/temporary-timeout-admin-2026-10-09.md.
  Inspect exact file sizes/status and commit this packet separately; no push.

Stop: native/browser checks PASS with truthful physical QA10 NOT_RUN. Root
integrates backend and client commits and transfers any remaining acceptance.
