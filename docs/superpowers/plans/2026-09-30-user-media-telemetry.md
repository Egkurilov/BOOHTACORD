# User media telemetry implementation plan

> Execute inline, packet by packet, in the existing isolated worktree.

**Goal:** Show each authenticated user's media RTT, send/receive bitrate, FPS, interval packet loss and target/actual stream quality in Grafana.

**Architecture:** Extend the bounded `/voice/screen-metrics` report with numeric measurements and fixed enums. Emit one `media.sample` span per fresh report with server-verified account/session attributes. Preserve aggregate Prometheus metrics without user labels. Use current WebRTC measurements; omit unavailable values and discard stale generations. Show sample timestamps and units in a filtered Grafana table.

**Tech stack:** Go OTel, Vue/TypeScript LiveKit, shared Flutter LiveKit, Tempo/Grafana.

## Operating brief

- workflow_class=split_first; task_size=large; route=T-052 + T-030 measurement producers.
- Native edges: authenticated screen report route -> report handler -> OTel; existing sender/receiver and voice sampling -> report builders -> authenticated endpoint.
- No project-local SKILL.md/structure.config.yaml. Preserve existing structure and behavior; no unrelated conversion.
- New leaf files target 100/hard 120 lines; keep existing large integration files to narrow binding changes.
- Profile names are allowed in private spans by the explicit follow-up request; never metric labels/access logs. No cookies, raw session digests, track/room IDs, IPs, SDP or content in telemetry. Client metrics remain untrusted diagnostics.
- Stop: native checks pass, production API/web and saved Grafana expose measured per-user samples; native source validated and build limits recorded.

## Packet 1 — authenticated ingestion

Files: `backend/internal/observability/http_metrics/client_screen_report.go`, new `client_media_validation.go`, `backend/internal/observability/report_client_screen/api/record_media_sample.go`, `http_handler.go`, focused tests, `contracts/openapi.yaml`.

- [x] Add failing Go tests for bounded packet_loss_percent/window_ms, target quality, connection quality, platform enums, fresh sample age and verified identity.
- [x] Run `go test ./internal/observability/http_metrics ./internal/observability/report_client_screen/api` and observe failures.
- [x] Extend the strict report with optional fields. Preserve existing sender/receiver payloads. Add direction `connection` for voice RTT/quality.
- [x] After successful validation emit `media.sample` with `correlatesession.Attributes(principal.AccountID, principal.SessionDigest)`. Attach only allowlisted numeric and enum fields; no caller-supplied identity.
- [x] Validate interval percent/window together; omit absent values, preserve real zeros. Record server receive time and sample age. Update OpenAPI and run contract guard.

## Packet 2 — web collection

Files: `frontend/src/voice/screen_packet_loss.ts`, `screen_livekit_diagnostics.ts`, `screen_diagnostics.ts`, `screen_client_reporter.ts`, new report helpers under `frontend/src/telemetry/report_media/`, `screen_sender_reporting.ts`, `ScreenViewer.vue`, `connection_store.ts`, `voice_connection_quality.ts`, `livekit_room_factory.ts`, nearest tests.

- [x] Test sender loss as delta lost / delta sent, receiver loss as delta lost / (delta received + delta lost), approximately ten seconds. Reset on counter/track changes or gaps.
- [x] Report selected sender resolution/FPS separately from measured dimensions/FPS. Include measured bitrate, RTT, adaptation reason and connection quality.
- [x] Send receiver interval loss and freshness through the existing five-second reporter. Suppress stale samples.
- [x] Report fresh voice RTT/quality at most every five seconds. Preserve voice controls when reporting fails. Cover listener/candidate-pair RTT.
- [x] Run focused Vitest tests and `npm run build`.

## Packet 3 — shared native collection

Files: new helpers under `desktop/lib/src/telemetry/report_media/`, `desktop/lib/src/services/screen_receiver_report.dart`, `screen_share_metrics.dart`, `desktop/lib/src/screens/screen_packet_loss.dart`, `screen_receiver_diagnostics.dart`, narrow `desktop/lib/src/app_state.dart` bindings, matching Flutter tests.

- [x] Test interval loss, counter reset, missing values and all native platform names including iOS.
- [x] Add per-track sender loss and target quality to existing report; use actual sender stats and guard stale generations.
- [x] Add receiver loss window and stale-sample checks. Report fresh connection RTT/quality from existing peer-connection polling.
- [x] Run Flutter tests/analyzer and supported builds. Record unavailable physical-device/macOS validation.

## Packet 4 — Grafana and delivery

Files: `docker/observability/dashboards/traces.json`, `scripts/observability/test_traces_dashboard.py`, `docs/OBSERVABILITY_TRACES.md`, release evidence.

- [x] Test media table queries filter verified user/session and select RTT, bitrate, FPS, loss/window and target/actual dimensions with units.
- [x] Add a dedicated media samples table and keep routine samples out of the user-action panels. Explain sender vs receiver, missing values, sample age and bounded search.
- [x] Validate TraceQL against private deployed Tempo and dashboard response field names in Grafana.
- [x] Inspect status/diff/file sizes, commit exact files, integrate current master and push. Wait for CI/deploy, update Grafana and verify stored sample attributes.
- [x] Record live evidence and any unsupported platform/device checks without claiming unmeasured media capacity.

## Packet 5 — readable authenticated profile names (user follow-up)

- [x] Load display_name with the current verified session; add user.name/user.label only to private spans.
- [x] Test forged headers, missing identities, renames and duplicate names. Keep the session hash unchanged.
- [x] Show name plus ID in the user dropdown with UUID as its value; retain stable grouping, old ID links and unnamed history.
- [x] Add name columns to summaries and history, validate TraceQL on deployed Tempo.
- [x] Deploy and verify real profile names and available media sample attributes; record partial runtime limits in evidence/observability/2026-10-01-user-media.json.
