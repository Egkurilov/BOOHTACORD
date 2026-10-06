# User-flow tracing implementation and isolated runtime

Status: **PASS_STATIC / PASS_RUNTIME_PARTIAL; acceptance gates remain open**.
Date: 2026-10-07 (Europe/Moscow). Executor/observer: Codex, local Windows + WSL Ubuntu.
Scope: #144 and #145–155. No production mutation, client release or deployment.
Tested source: `ec62b3af983634e8c60366069da1f3d099911c04`.
Includes master `e4cace80`; original base `ad63694b`. Later evidence/QA documentation
does not change the tested production implementation. Run metadata: accompanying JSON.

## Environment and reproducibility

Go 1.26.4; Node 24.18.0; Flutter 3.47.5 / Dart 3.13.4; native lock files retained.
Docker 29.1.3 / Compose 2.40.3, isolated `boohtacord-tracing-qa` namespace.
Collector 0.161.0; Tempo 2.10.3; PostgreSQL 17.6; LiveKit 1.13.7.
Optional existing Prometheus 3.11.2 service used for actual PromQL execution.
SDK pilot sampling: 100%. Synthetic principals, synthetic canvas video, isolated DB
schemas. Production session cookies and actual user content were not used.
[Exact runtime commands and boundaries](../tools/qa/tracing_flow/README.md).
Logs are local `.out/tracing-qa/`; SHA-256 receipts are in the companion manifest.

## Checks at the tested source

| Check | Observed result |
|---|---|
| Go `test ./...`, real isolated PostgreSQL | PASS; 280 passing test packages |
| Go `vet ./...` | PASS |
| Web Vitest / `vue-tsc --noEmit` | PASS; 1180 tests / 379 files |
| Flutter `test --no-pub` | PASS; 689 tests, one opt-in runtime skipped in default suite |
| Flutter actual SDK/frame runtime | PASS separately; Windows Flutter test engine |
| Flutter analyze `--no-pub --no-fatal-infos` | PASS; zero errors/warnings, 37 existing info diagnostics |
| Generated contract / API contract / traceability | PASS; 39 approved requirements referenced |
| Dashboard regression | PASS; 14 tests preserve UID, legacy views and filter semantics |
| Actual Tempo TraceQL | PASS; all 21 dashboard queries return HTTP 200 |
| Actual Prometheus PromQL | PASS; panels 46/47 return success with one synthetic series each |

The Flutter test engine is not a packaged Windows/Android/macOS/iOS application.
Info diagnostics outside the edited tracing code were retained.

## Ten-scenario acceptance matrix (#154)

| Scenario | Proven result | Remaining acceptance |
|---|---|---|
| 1. Voice join + view | Stage/outcome regressions and first-frame observer integration PASS | NOT_RUN: full live voice lease/credential/connect/publish + two real clients |
| 2. Missing first frame, retry | Actual Chromium waits 120s; `first_frame` timeout attempt 1 and presented-frame success attempt 2 share flow | PASS for synthetic video; no acoustic/FPS quality claim |
| 3. Lost message response | Actual Vue send/store/item + relay/Tempo; one POST, delivery lookup, sender render and separate receiver render PASS | Business API responses synthetic; NOT_RUN complete Go business/realtime graph with two clients |
| 4. Visits and parallel actions | Actual two Chromium contexts have distinct visits; concurrent/nested root isolation regressions PASS | Parallel SDK/unit coverage does not replace a full live two-tab voice scenario |
| 5. Account change | Actual browser reset drops stale batch; A→B/in-flight late ACK regressions PASS | NOT_RUN production logout/login cookie transition with a pending exporter |
| 6. Native origin/generation | Origin/SessionTicket/replaced-owner guards and late callbacks PASS | NOT_RUN packaged native server switch/background/device matrix |
| 7. WebSocket/replay | Actual Go socket handshake ends while socket is open; real PG replay/ACL and client coalescing regressions PASS | NOT_RUN single integrated two-client reconnect/replay graph through Tempo |
| 8. Revoke/outbox/restart | Real PG commit, rollback and crashed claim/reclaim; worker retry then actual SFU `participant_absent`, links retained in Tempo PASS | No connected participant; NOT_RUN physical media cessation |
| 9. Relay/privacy | Mixed acceptance stored in real Tempo; spoof/body/raw proof stripped; signed audience and malformed/legacy budgets regressions PASS | Source/device rollout remains separate |
| 10. Export failures | Actual Tempo outage/recovery and stopped Collector PASS; 429, queue bounds, reset and sampling regressions PASS | NOT_RUN live voice continuity during telemetry outage and sustained client/platform pilot |

No row with a NOT_RUN remainder is a completed release/device acceptance gate.
The synthetic browser receiver event has no signed sender cause; signed cross-user
causality is verified by relay/HMAC tests and the separate real outbox graph.

## Actual stored observations

- Browser profile: `browser-final.log`, 125.09s. Sender 49 records, receiver 32,
  including periodic diagnostic health. Per product action: message.send 7 records;
  screen.view timeout 5; successful retry 8. Actual terminal records were fetched
  from Tempo and checked for flow IDs and absence of message-body sentinel.
- Native test-engine trace: `8be7e2a83a2c96395993e19a83483673`.
  Actual OTel SDK → native transport → production relay → Collector → Tempo;
  terminal only after mounted frame. Fixture runtime 11.19s including launch.
- Relay sanitized trace: `f0f7985d9cc3b59f39aa32f13015cc57`; one accepted,
  one rejected; stored HMAC-verified link, verified identity, no raw proof/body.
  Send-to-stored assertion completed in 1.02s (one fixture, not a latency SLO).
- Worker attempts: `d82a663ff7445c843ef8d9f175bbf130` (dependency outage),
  `1fcea01cb369101e3ddad7fb98afe0e1` (actual SFU participant absent).
  Original command `07a9f662db1838f16258f789ffe7c66d` linked to both attempts.
- Actual Collector metrics include `boohtacord_telemetry_relay_records_total`
  and `boohtacord_telemetry_relay_last_accept_seconds`. Labels are fixed reasons/
  status classes; user/session/visit/flow/media IDs are not metric labels.
- Final-source stopped Collector: relay 503 in 2000ms, no acceptance receipt. Tempo outage:
  relay accepted while Tempo unavailable; after restart, trace found within 30s.
  Final-source replay took 19.55s, stored synthetic trace
  `35b908fb205627cbe0081f87018e74ee`. Collector/Tempo were restored before healthy checks.

## Resource observation, not capacity or overhead evidence

During the two-context synthetic Chromium timeout wait: five owned headless Chrome
processes, 366.33 MiB combined working set, 0.210% of one CPU core over 29.71s.
Single container snapshot: Collector 19.28 MiB / 0.30% CPU; Tempo 115.4 MiB /
0.32%; PostgreSQL 57.96 MiB / 0.02%; idle SFU 14.66 MiB / 0.05%.
Concurrent unit tests, startup and idle timing affect these numbers. No baseline
subtraction, production completeness, overhead bound or media capacity is proven.
Query results are bounded to configured limits; an absent terminal means unknown,
and stale/unsupported numeric measurements remain absent rather than zero.

## Grafana (#155) and stop condition

Read existing authenticated dashboard `boohtacord-traces`, org 1. Export API version
`dashboard.grafana.app/v2`, generation 13, resourceVersion `1790842200468009`;
saved-from-UI annotation Grafana 13.0.2. Datasource UIDs confirmed from actual UI:
`boohtacord_tempo` and `boohtacord_metrics`. Existing queries/deep links preserved.
Repository JSON adds visits/flows/media filters, stage/history/media/worker/health
views and honest incomplete/legacy handling. Production version was **not updated**.

NOT_RUN: production source/provisioning reconciliation, datasource/dashboard ACL
acceptance, synthetic visual smoke, concurrency-safe save and verified rollback.
#155 explicitly requires #145–153 and completed #154 acceptance before final rollout.
**#144/#154/#155 remain open; implementation PR must not auto-close these gates.**
Full device/live-media and production pilot follow this source handoff. No public
snapshots, real user identifiers, credentials or media payloads are in this evidence.
