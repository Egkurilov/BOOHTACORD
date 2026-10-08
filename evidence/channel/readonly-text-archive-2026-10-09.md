# IMP-05 / #92: explicit read-only TEXT archives

Date: 2026-10-09 Europe/Moscow. Source base: `0eaee217e92078b702e280a58b16561a81b1691a`; archive packet is recorded by its delivery commit. Status: focused source, real PostgreSQL and real browser component acceptance PASS; full application release acceptance NOT_RUN.

## Product and privacy boundaries

ADR-021 adds an explicit readable archive action. Existing DELETE archives default to `readonly_archive=false` and stay inaccessible. Only active readers can use separate archive history/search/download URLs. Only an active administrator can archive/restore. Channel ID, category, position, history and file references remain; VOICE and DMs are not included. Restore does not reinstate welcome-channel settings.

Every existing live history/search/download URL still rejects archives. Fresh send, old idempotent send replay, edit, message deletion, upload authorization and finalization reject archives. History/search data SQL rechecks the archive state and actor block after the availability probe. No message bodies, attachment contents, credentials or real identity details are retained in this evidence.

## Observed checks

- PASS: real isolated PostgreSQL 17, four tests, 37.836 seconds: archive/restore and revision conflicts; active-member/admin versus blocked-user reads; inaccessible DELETE/VOICE exclusions; same ID/history; welcome clearing and audit; protected/hidden files; old URL denial; fresh and idempotent send/edit/delete/upload rejection; deterministic account block between probe and data SQL. Each fixture applies all 50 embedded migrations and drops its own schema.
- PASS: focused archive/restore/list service and API tests; history/search/download suites; archive data query negative test failed before adding the SQL guard and passed afterwards.
- PASS: native Go vet for all changed capability leaves and native composition edge.
- PASS: complete Web suite, 435 files / 1361 tests.
- PASS: `npm run build`, including vue-tsc, using explicit test origin `https://archive-verification.example`. Initial build without required public-origin configuration correctly rejected missing configuration.
- PASS: real headless Chromium, `npm run test:readonly-archive`, 2 tests. Actual SearchPanel/ArchiveReader/ArchiveManagement components exercise escaped history, cursor paging, archive search/file URL, absence of composer/admin tools for member, session unmount, confirmation, expected revision, visible restore conflict. HTTP fixtures are synthetic; this is component browser acceptance, not deployed API integration.
- PASS: `python -m tools.ci.native.contracts`: 19 contract checks, OpenAPI schema lint and 96 public operations / 3 private exclusions; 39 requirement traceability; docs/native-edge/topology/delivery checks. Tooling suite: 241 tests with one pre-existing skip, separately from unskipped archive PostgreSQL acceptance.
- Full Go package suite: initial run found the expected migration fingerprint list missing 0050. The exact readonly default/state constraint fingerprint was added; native migration suite subsequently PASS. Final clean aggregate re-run `go test ./... -p 4 -timeout=180s` PASS (database integration environment unset; real archive PG acceptance is listed separately).

## Remaining acceptance

NOT_RUN: deployed authenticated browser end-to-end archive lifecycle against the real API, live session block/revoke and reconnect across clients, supported native clients, production upgrade/rollback. Before release, record exact delivery SHA, environment and sanitized timing/result; verify a member reads an explicit archive, an admin restores the same ID, a blocked user receives no history/files, DELETE archives remain inaccessible, stale send/edit URLs fail, and normal voice/DM behavior continues. Focused unit/PG/component results do not prove those release checks.
