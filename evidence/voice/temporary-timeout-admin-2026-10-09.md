# Voice timeout Web administration (#97)

Date: 2026-10-09. Scope: real AdminMembersSection desktop action menu and mobile
member editor bound to ADR023 GET/PUT/DELETE routes. Source: admin/voice_timeout.

## Observed verification

- Preservation baseline: 16 existing member-directory/client tests PASS before
  edits. New wire/lifecycle tests first failed because implementation was absent.
- PASS: 23 focused Vitest tests including cookie paths, strict wire parsing,
  bounded error feedback, loaded-state mutation guards, no disposed late writes,
  AbortController, expiry/reason request and durable-pending lift state.
- PASS: full Web suite, 434 files /1353 tests; `npm run build` includes vue-tsc
  and production Vite build using synthetic VITE_PUBLIC_ORIGIN.
- PASS: actual Chromium4/4 cases at390 and1440 px, mounting the real member
  directory and child control. Assertions cover lazy selected-account read,
  keyboard opening, explicit reason/expiry PUT, pending202, manual DELETE,
  no automatic media requests, bounded403, stale-form removal, lift focus
  restoration and horizontal overflow. API responses are route mocks.
- Initial cold Vite/browser navigation exceeded30s during concurrent checks;
  final run uses explicit DOM-content readiness and completed4/4 in4.2s.

No account role, block, password reset, TEXT/DM or voice lifecycle was changed.
Timeout operations never call Join, microphone or capture APIs. Server database
clock is authoritative; invalid/client-clock expiry displays a bounded error.
No request starts for every member merely because the directory mounts.

## Remaining acceptance

NOT_RUN: physical QA10 SFU removal/token replay and device media behavior.
The browser mocks do not prove those gates; the separate backend evidence proves
real PostgreSQL serialization and durable intent. Native Flutter admin controls
are a separate parity packet. Existing Web admin and server ACL remain binding.
