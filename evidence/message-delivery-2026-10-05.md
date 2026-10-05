# Delivery uncertainty — issue #71

Route: chat/lookup_message_delivery; Web conversation/delivery_uncertainty;
Flutter conversation/delivery, text/send_state and direct/send_state.
Preservation baseline: exact-payload idempotency and per-conversation pending maps.

## Implemented

- Metadata-only caller-author receipt by conversation/client UUID. Foreign DM
  is unavailable even to an administrator; deleted committed rows remain delivered.
- Vue and Flutter show sending/checking/failed. Timeout or uncertain response
  checks receipt then addressed history; committed rows replace optimistic rows.
- Manual identical retry checks first, then sends the original UUID/payload only
  if absent. Changed payload gets another UUID. Lookup failure prevents blind POST.
- 400/403/409/507 block retry of the rejected payload. Upload 507 remains distinct;
  no media/attachment feature removed. Failed local removal performs no DELETE.
- Requests are bounded to 20 seconds; late commits retain the original UUID.
  Pending queues survive conversation navigation and clear on account/server exit.
- Response-owner and generation guards discard changed account/screen results.
  Existing secure cookies, Origin boundaries and server idempotency preserved.
- Mixed Web send implementations moved to a dedicated leaf and native status UI
  moved into a shared capability; no duplicate forwarding implementation.

## Observed checks

- PASS: real PostgreSQL + HTTP POST commits, connection drops before response,
  receipt finds the row; an exact resend still leaves one persisted message.
- PASS: PostgreSQL caller/foreign-author boundaries, private DM access and deleted
  delivery receipt; API UUID/auth/no-store tests.
- PASS: full Web suite: 1063 tests before the additional timeout case; production
  vue-tsc/Vite build. Timeout case is included in the final integration suite.
- PASS: full Flutter application suite: 600 tests, including AppState and actual
  failed-send UI. New lookup and generic recovery tests cover changed owner/scope.
- PASS: four Chrome actual-component checks at 390/1440 widths: response-loss
  reconciliation, second browser context sees one row, 403 retry disabled and local
  removal sends no DELETE. Browser API fixture is mocked; PostgreSQL proof is above.
- PASS: native OpenAPI/mobile contract validator. New browser checks are included
  in the canonical tools.ci.native.web entrypoint.

## Limits

Whole integration CI passed; publication is recorded in
[integration evidence](critical-five-release-2026-10-05.md).
Physical Android media lifecycle acceptance is NOT_RUN. These checks do not
claim hardware capacity or production media quality. Production user content untouched.

Slavik Gym report: route=split_first; packet=delivery-uncertainty; tokens=estimated:16000;
method=manual_estimate; driver=lost-response-idempotency; next_split=guild-settings.
