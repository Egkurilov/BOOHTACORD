# Owned session controls — issue #63

Route: identity/list_own_sessions, identity/revoke_own_sessions, Web identity/
own_sessions, Flutter session/own_sessions. Baseline: dcef7fe4.

## Implemented

- Random public session handles; fixed generic label, created/activity timestamps,
  current marker. Caller-owned seek pages, no-store, no token/digest/IP/fingerprint.
- Selected/all-other revocation under account lock; initiating session revalidated,
  foreign handle returns 404. Session and lease changes plus SFU queue are atomic.
- Private empty account-targeted hint prompts immediate WebSocket revalidation.
  Existing periodic revalidation covers missed hints; no private global event.
- Web and Flutter settings list/reload/more/revoke controls, current row disabled.
  Generation guards discard stale account/server/screen responses. Response owner
  and required X-Account-ID protect against browser cookie owner changes.
- Existing secure cookie, trusted Origin, server authorization and media transport
  preserved. Administrator status grants no access to another member's sessions.

## Observed checks

- PASS: real PostgreSQL 17.6 disposable schemas, API isolation/account conflict,
  durable voice queue, old/current cookie behavior, migration suite.
- PASS: two real WebSockets; old socket closes with 1008 before the one-hour
  periodic check, initiating socket/cookie remain valid.
- PASS: previously issued LiveKit SDK credential admits before revocation and is
  denied afterwards by the real signal admission service and PostgreSQL repository.
- PASS: 23 focused Web tests and vue-tsc/Vite production build.
- PASS: seven Flutter API/controller/widget tests; focused analyzer no issues.
- PASS: four actual component Chrome checks at 390/1440 widths, current protection,
  revoke/refresh hint, account mismatch/expiry and no horizontal overflow.
  Browser API fixtures are mocked; they are not production ACL evidence.
- PASS: native OpenAPI/realtime contract validator.

## Limits

No production accounts or messages changed. Physical SDK disconnect/Android device
acceptance is NOT_RUN; durable queue/admission evidence does not claim audible media
cutoff or hardware capacity. Whole integration CI passed; see
[integration evidence](critical-five-release-2026-10-05.md).

Slavik Gym report: route=split_first; packet=owned-sessions; tokens=estimated:18500;
method=manual_estimate; driver=account-and-media-invalidation; next_split=delivery-uncertainty.
