# Autonomous acceptance without operator participation

Status: isolated actual application journey PASS at 1440 and 1024 px.
Base: ffa4efcc3b5599ff531420caefd144de5860d865, with the authentication introduction
repair in this packet. CI artifacts bind subsequent executions to the actual
checked Git revision and source hashes. This is not a production/device receipt.

## Executed stack and journey

Two independent Chromium cookie stores open the built production Vue App.vue,
through local TLS Caddy 2.10.0, the actual Go API, disposable PostgreSQL 17.6 and
Tempo 2.10.3. No API routes, WebSocket events or application stores are mocked.
All accounts, channel names, messages and credentials are synthetic and confined
to the disposable stack. Each width starts a fresh database.

| Check | Result |
| --- | --- |
| Login through the real form; secure/HttpOnly/Lax cookie | PASS |
| Real admin guild save; second client's live name and title | PASS |
| Stale administrator revision rejects overwrite with 409 | PASS |
| Member and foreign Origin reject administrative mutations | PASS |
| Anonymous profile contains only name and revision | PASS |
| Registration appears once in both open TEXT views | PASS |
| Reconnect/reload and repeated registration do not duplicate welcome | PASS |
| Foreign session handle inaccessible even to administrator | PASS |
| Addressed revoke via actual settings; old WebSocket closes | PASS |
| Replay of the captured old cookie rejects with 401 | PASS |
| Initiating and unrelated member sessions remain valid | PASS |
| Actual OTLP export queried from disposable Tempo | PASS |
| Register root and welcome child share trace and correct parent/subject | PASS |
| Trace excludes password, message body and raw guild name | PASS |
| Lifecycle Prometheus labels contain only bounded outcome | PASS |
| Owned API restart preserves guild profile and one welcome | PASS |
| Owned API, proxy, database, Tempo and network removed | PASS |

Five actual screenshots per width: guild settings, both welcome views, owned
sessions and authentication. Reports contain hashes and bounded outcomes only.
Private cookies, registration handoff and raw traces are not retained/uploaded.
The 1024 px independent local run completed in 77.4 seconds after dependencies
and API binaries were prepared; this is fixture duration, not a product p95 claim.

## Defect and validation

The auth brand already used the public guild profile, but its introduction still
contained hardcoded `Моя гильдия`. Two real-component SSR regressions failed,
then passed after binding the introduction to the same reactive public name.
Vue escapes `<`, `>` and `&`; authentication and registration behavior is unchanged.

- Web: 1102 tests / 344 files PASS; vue-tsc and Vite build PASS.
- Fixture safety/correlation/privacy: seven regressions PASS.
- Native Python: 128 tests successful, including one existing Windows platform skip.
- Contracts, 39-requirement traceability, imports, workflow and links PASS.
- Fixture setup failures were repaired rather than retried to hide failures:
  Docker internal bridge suppressed published ports; proxy readiness was missing;
  host browser lacked shared libraries. Browser dependencies were installed in
  an owned container. Cookie and route expectations were aligned with the exact
  existing handler/tests (`Lax`, `POST /api/v1/auth/register`), preserving contracts.

## Repeat autonomously

`.github/workflows/client-lifecycle-acceptance.yaml` runs the two fresh journeys
on relevant pull requests or workflow dispatch, and retains the actual PNGs and
bounded reports for 30 days. Prerequisites: local Linux Docker, locked Node/Go,
`npm ci`, `npx playwright install --with-deps chromium`.

```sh
python3 -m unittest tools.qa.client_lifecycle.test_services tools.qa.client_lifecycle.test_telemetry
python3 -m tools.qa.client_lifecycle.run --width 1440
python3 -m tools.qa.client_lifecycle.run --width 1024
```

Only the localhost TLS origin and local Linux Docker daemon are allowed. Ports
are checked before allocation; resources carry a random ownership label and are
verified before removal. No production mutation or microphone is needed.

## Issue acceptance boundaries

| Issue | Autonomous evidence | Remaining original criterion |
| --- | --- | --- |
| #63 | Real cookie, ACL, UI and immediate WebSocket revoke PASS | Connected media/old SDK credential device path |
| #100 | Real Web rename, concurrency, auth/header and persistence PASS | Android/Windows Flutter actual screenshot/device parity |
| #101 | Real two-client welcome, uniqueness and persistence PASS | Android/Windows realtime/device parity and complete original matrix |
| #102 | Real isolated API → Tempo correlation and bounded counters PASS | Production Grafana dashboard/smoke acceptance |
| #95 | Existing isolated UDP/TCP failure/restoration matrix PASS | Actual home/hotspot; applicable media/revocation/capacity gates |
| #105/#107 | Existing shared native DSP, model/widget and synthetic media checks | Physical pre-publish gain and audible restored participant level |
| #110 | Existing actual synthetic LiveKit RTP/DTX/RED profile measurements | Same-source Web/Windows speech quality and blind acoustic A/B |

Network shaping emulates filtering, not a measured hotspot. Synthetic PCM checks
gain, silence, transport and resource ownership, not microphone-driver behavior
or perceived speech quality. No physical or production NOT_RUN is promoted to
PASS by this packet; these issues remain open under their original criteria.
