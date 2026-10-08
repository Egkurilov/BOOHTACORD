# Roster production diagnosis and observability

Route: `review_gate` for #266/#267; separate `small_direct` implementation packet for #271.
Doctrine: preserve ACL, lease intersection, media lifecycle, private SFU/DB interfaces.
Ratchet: production files target 100/hard 120 lines; child capabilities target 8/hard 16 files.
Backend metrics and recovery belong to the concurrent #268/#269 packet.

## Read-only production packet

- [x] Inspect deployed image SHA, safe endpoint config, network membership and health.
- [x] Compare private authenticated RoomService ListRooms with API roster stage counters.
- [ ] Probe the exact Go snapshot client in the API network namespace; retain only sanitized stage/outcome/counts.
- [ ] Compare bounded authenticated REST/SSE if an existing authorized session is available.
- [ ] Record confirmed/rejected/unverified causes in `evidence/2026-10-08-roster-production-rca.md`.
- [ ] Apply configuration change only for a demonstrated configuration defect; otherwise record NO_CONFIG_CHANGE.

## Observability packet

- [ ] Write focused Python checks in `tools/verify/voice_roster_observability/` before implementation.
- [ ] Add `docker/observability/dashboards/voice-roster.json`: bounded stage/outcome metrics, TTFB/SFU p95, active streams, freshness and explicit missing data.
- [ ] Add private rules in `docker/observability/voice-roster-alerts.yaml` with sustained failure/timeout/freshness signals; gate idle signals on activity.
- [ ] Wire rules through exact `docker/observability/prometheus.yaml` and `compose.yaml` edges.
- [ ] Add `docs/operations/voice-roster.md`: stage isolation, SHA/config checks, dependencies and rollback decision.
- [ ] Export roster observations through existing authenticated OTLP provider (backend agent owns source); central Collector currently does not scrape API.
- [ ] Validate JSON, PromQL/rules via pinned promtool, focused Python tests, Compose config, then synthetic alert behavior.
- [ ] Record source/synthetic PASS separately from production scrape/dashboard/alert acceptance.

Stop condition: verified development and explicit remaining acceptance; no fabricated production/device PASS.
Unresolved: authenticated current API session, actual failure cause, production baseline alert thresholds.
