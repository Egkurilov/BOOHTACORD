# Guild people quick jump and notification title (#78)

Status: source and automated checks PASS; physical acceptance NOT_RUN.
Owner approved retaining BOOHTACORD logo and using configured one-guild name.

Actual WorkspaceSearchPanel loads the existing server-authorized DM candidate
endpoint only in navigation mode, pages explicitly and deduplicates existing DMs.
New member selection uses secure-cookie DM creation, then authoritative navigation
refresh before opening. Failed refresh, denied creation and disposed responses do
not navigate. TEXT jump refreshes topology; no voice Join is introduced.
Search no longer mounts a second voice controller that rebinds microphone account
ownership. Existing message search/mentions state and parent focus return remain.

Web and Flutter generic notifications read the current configured guild name at
delivery, retaining stable application identity, generic bodies and scope guards.

Checks on 2026-10-09:
- Red first: missing people modules, hardcoded Web title, missing native title
  callback, and search owning voice lifecycle. Focused checks subsequently PASS.
- Full Web: 444 files / 1381 tests PASS; vue-tsc and Vite production build PASS
  with explicit disposable origin https://localhost:4810.
- Actual Chromium: 2/2 PASS, widths390/1440, real Vue composition with stub API
  transport. Paging failure/retry, member POST and navigation refresh checked.
  No Join request and no horizontal overflow. This is not production ACL evidence.
- Native notifications: 8 tests PASS; scoped Dart analysis no issues.
- Combined archive/timeout contracts: 255 native contract tests (one unavailable
  platform check skipped), 19 parity tests, 99 public operations, 39 brief
  requirements PASS. Migration fingerprint regression PASS.

Pending: Flutter member quick jump parity; physical OS notification presentation,
screen reader/IME and production eligible-member revocation acceptance in #283/#278.
No physical, production or release gate is claimed PASS by these fixture tests.
