# User flow tracing implementation plan

> Execute inline in dependency order, one leaf packet at a time.

**Goal:** implement #144 and #145–155 preserving ACL, idempotency and media lifecycle.
**Architecture:** short versioned records, explicit ActionScope, server session binding,
validated causal references, existing OTel/relay/Collector/Tempo, existing dashboard UID.
**Base:** ad63694b129bc9c5e40461353ea436c9948d98e3.
**Route:** split_first; large; native structure; T-052 (T-010/T-014/T-044 dependencies).
**Ratchets:** new source <=120 lines; one trigger per leaf; target 8 files.
**Baseline:** legacy sanitized audio operations, HTTP parent propagation, session generations,
protected refresh coalescing, DB commit/outbox retry and physical first-frame callbacks.
**Stop:** all code/checks and evidence; unavailable runtime explicitly NOT_RUN, never gate PASS.

- [x] #145 contracts/telemetry-flow-v1.json, ADR, generated Go/TS/Dart validators and fixtures.
- [x] #146 ingest_client_traces: version/session validation, partial acceptance, links, privacy.
- [x] #147 web telemetry/action_scope; auth, send-render, join and first-frame integration.
- [x] #148 flutter features/telemetry/action_scope; existing SessionScope and origin guards.
- [x] #149 trace_http/auth middleware and domain edges; fixed stages, truthful outcomes.
- [x] #150 event_hub/connect_session, client protected refresh; bounded verified cause metadata.
- [x] #151 dispatch_voice_sfu_revocation + enqueue stores; transactional durable cause migration.
- [x] #152 media reporting: bounded samples, session rotation, provenance, stale/unknown.
- [x] #153 bounded session exporter; retry/status/sampling/rollout policy.
- [x] #154 tools/qa flow harness: actual relay/Collector/Tempo, adversarial regression matrix.
- [x] #155 docker/observability/dashboards existing boohtacord-traces; query fixtures/runbook.
- [x] Fixed-SHA runtime and evidence; draft PR handoff with acceptance gaps.

**Checks:** nearest Go packages; Vitest/TypeScript; Dart unit/widget/analyze; contract and
spec traceability validators; isolated Collector/Tempo smoke when available. No release builds.
**Unresolved:** production Grafana read/access and native runtime availability assessed in
verification packet. Diagnostic headers are not authorization and do not change API outcomes.


## Delivery state (2026-10-07)

Checked items above mean implementation artifacts, not production/device gate closure.
Go full tests with real isolated PostgreSQL and go vet PASS; Web full tests/typecheck
PASS; Flutter full tests PASS with opt-in runtime test skipped and run separately.
Actual Windows Flutter engine SDK/frame observer -> relay -> Collector -> Tempo PASS.
Actual two-browser Vue components and 120s first-frame retry PASS at ec62b3af.
Real outbox restart/retry -> pinned SFU participant_absent -> Collector/Tempo PASS.
Actual Collector outage and Tempo outage/recovery PASS at ec62b3af. All 21 TraceQL queries PASS locally.

Remaining mandatory acceptance: full voice+screen/live participant and platform
matrix, production data rollout/health, Grafana synthetic UI/ACL/source comparison,
concurrency-safe update and rollback. These keep #144/#154/#155 open. Production
Grafana was read using existing authenticated browser; no deployment was performed.
Current export generation 13, dashboard.grafana.app/v2. Metrics UID is boohtacord_metrics.

Final source: ec62b3af983634e8c60366069da1f3d099911c04. Go test/vet PASS; Web 1180; Flutter 689 + separate native runtime PASS. Production/dashboard gates remain open. See evidence/tracing-user-flow-2026-10-07.md and JSON receipts.
