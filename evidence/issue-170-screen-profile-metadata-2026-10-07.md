# Issue #170 — screen profile and metadata evidence

Date: 2026-10-07. Route: Web screen sharing + Go lease descriptor writer.
Base: `dee50f1b6c637a673f8a6b670ecac45fd4bcf463`.

## Implemented

- Web screen sharing exposes text/motion modes, profile ceilings, account and
  origin scoped preferences, sender target/effective encoding, receiver actual
  quality, and sample age. Audio is reported from the actual LiveKit screen-audio
  publication; ADR-018 v1 was not extended.
- Viewer descriptor parsing validates version, owner scope and monotonically
  newer revisions. Initial snapshots and attribute-change events both update
  metadata, including late joiners.
- The Web publisher sends descriptor fields through a session-authenticated API.
  The server validates configured Origin and CSRF/session scope, derives account
  and room from the active authorized lease, and writes only the descriptor
  attribute. A lease-row lock serializes revisions across API processes; exact
  retries are idempotent.
- The LiveKit service token remains without participant self-metadata/name/
  attribute grants. The server writer is room-scoped and updates only
  `boohtacord.screen-share.v1`.
- Stop, source-ended, room teardown, lease replacement, reconnect, failed profile
  rollback and watchdog repair are wired to publish idle or refreshed metadata.
- No legacy preference key was found in the bounded Web/Flutter search, so no
  preference migration is claimed. Descriptor v1 has no screen-audio capability;
  only the actual LiveKit publication is shown.

## Automated evidence

- **PASS** Web Vitest: 407 files / 1,269 tests.
- **PASS** `npm run build` with `VITE_PUBLIC_ORIGIN=https://v.bootybay.ru`;
  Vue typecheck and Vite production build completed. Existing dynamic-import and
  >500 kB bundle warnings remain.
- **PASS** Go descriptor/API/Postgres/LiveKit unit tests, migration tests and
  runtime tests via `go test ./internal/media/publish_screen_descriptor/...`
  `./internal/app/media_routes/screen_descriptor ./internal/app/runtime`
  `./internal/database/migrate/...`.
- **PASS** `tools/verify/contracts/verify-contracts.ps1` and `git diff --check`.
- **PASS** negative API/repository tests cover origin/session/lease scope,
  cross-account/channel attempts, stale revision, exact retry and conflict.

## Not run

- **NOT_RUN** real PostgreSQL integration and multi-process row-lock contention;
  `VOICE_PLATFORM_TEST_DATABASE_URL` is not configured on this host.
- **NOT_RUN** deployed LiveKit metadata update, browser-to-API end-to-end session,
  retry under network loss, and production room/lease teardown.
- **NOT_RUN** Flutter, Windows, macOS, Safari, Android and physical-device screen
  capture/profile matrix, including screen-audio behavior.
- **NOT_RUN** hardware-based bitrate/FPS adaptation and sample-age behavior under
  real constrained networks. Existing code does not provide an active adaptation
  supervisor in the production screen-share path.
- **NOT_RUN** legacy preference migration: no old preference key was found to
  migrate.
