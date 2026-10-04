# User metrics implementation plan

**Goal:** Show registered users, registrations and daily active users in Runtime.
**Architecture:** Aggregate users.created_at in PostgreSQL. Persist one activity row per
authenticated account and Moscow date; export aggregate gauges through the existing OTLP
pipeline. No account or session labels. Preserve authentication results on telemetry failure.
**Stack:** Go, pgx, PostgreSQL, OTel, Grafana/PromQL.

## Operating brief

- Packet: split_first; leaf: backend/internal/identity/observe_usage; backlog T-052.
- Integration edges: app/runtime, app/auth_routes, database/migrate, Runtime dashboard.
- Preserve existing authentication, ACL, collector and dashboard behavior.
- Ratchets: target 100/hard 120 lines; target 8/hard 16 implementation and test files per leaf.
- Activity: at least one valid authenticated server request per calendar day, Europe/Moscow.
- Total users includes all accounts, including blocked users and bootstrap administrator.
- Today registrations come from creation dates; DAU starts at rollout and has no fabricated past.
- Stop: unit/integration/metric tests pass, signed release deployed, queries and Grafana verified.

## Implementation

- [x] Write focused tests in observe_usage for Moscow rollover, daily deduplication, retry after
  failed writes, authentication preservation, aggregate labels, partial-day availability and
  PostgreSQL counts across yesterday/today. Run them before implementation and observe failure.
- [x] Add additive migration 0043: user_daily_activity(date, user_id), primary key(date,user_id),
  and a singleton collection-start timestamp. Migrations remain repeatable.
- [x] Add tracker.go and sessions.go. Successful authentication triggers a bounded 200 ms
  first write per user/day. Cache only successful writes, cap cache at 16384 entries, count
  write failures without logging identifiers; never turn telemetry failure into an auth error.
- [x] Add postgres.go and snapshot.sql. Read all-user totals and registration counts; count
  persisted daily activity. Retain 32 days of activity with date-indexed pruning on insert.
- [x] Add metrics.go: aggregate gauges for users, registrations and DAU today/yesterday,
  completeness and collection health. A one-second failed read publishes health=0, not zero users.
  Register/unregister at runtime and wrap only the existing session repository in auth_routes.
- [x] Run Go unit tests and PostgreSQL integration tests; full native backend CI remains the
  release gate. Add dashboard tests before the new audience panels and validate generated JSON.
- [x] Add total users with history, today/yesterday registrations, today/yesterday DAU and
  absolute/percent change. Gate yesterday comparison on complete historical collection.
- [ ] Update the runbook/evidence, inspect changed paths and sizes, commit scoped changes,
  synchronize master and use the existing signed build/deploy pipeline. Import Grafana JSON,
  validate live metrics and save the final screenshot.
