# Guild Lifecycle Observability Implementation Plan

> **For agentic workers:** execute the bounded packets inline in this worktree. The owner requested server dependencies #100/#101 with #102 and deferred builds and the scoped validation run.

**Goal:** Implement observable singleton guild settings and atomic registration welcome messages, without sensitive telemetry or changes to existing authorization.

**Architecture:** Settings use a singleton PostgreSQL row, optimistic revision and metadata-only audit. Registration creates the account and optional system welcome in one transaction, publishes only after commit, and keeps HTTP success if realtime publication fails. Child spans and bounded counters describe both operations; private actor attributes stay on spans.

**Tech Stack:** Go/pgx/PostgreSQL, OpenTelemetry, Prometheus, Grafana JSON, existing session/Origin middleware and realtime hub.

## Operating brief

- Route: `split_first`; backlog leaf T-052; packets: guild settings, registration welcome, lifecycle signals, dashboard/runbook, handoff.
- Preservation: keep one guild, registration bootstrap/unique-login gates, secure sessions, ACL, existing message behavior and migration history. Migration 0043 is occupied; add 0044 and 0045.
- Ratchet: new files target 100/hard 120 lines; split SQL, domain operations, adapters and HTTP bindings into their leaf directories.
- Checks: focused Go lifecycle/settings/registration/message tests and contract/dashboard checks; execution and production smoke are deferred by the owner. Evidence must say NOT_RUN, never PASS for an unexecuted check.
- Stop: implementation and focused regression tests committed and merged to master with `[skip ci]`; no new builds or deploy.

## Packet 1 — singleton guild settings

Create `backend/internal/guild/update_settings/{model.go,validation.go,postgres/repository.go,api/{handler.go,patch.go}}`. Public response is only name/revision. Admin PATCH accepts name and/or nullable welcome_channel_id plus expected_revision, rejects unknown fields, validates active TEXT channels, and atomically updates settings/audit. Realtime profile hints contain revision only. Wire `app/guild_routes/register.go`, protected route fixtures and OpenAPI.

Add tests before implementation for Unicode names, rejected fields, public-data boundaries, administrator role, optimistic conflict, transaction rollback and post-commit publication.

## Packet 2 — registration welcome

Create `identity/registration_welcome/{phrases.go,postgres/{repository.go,statements.go}}`. Register persistence receives the normalized account; welcome metadata remains private to the transactional adapter and observer. Lock settings/channel consistently with archive, use a fixed cryptographic phrase catalogue, insert `SYSTEM_WELCOME` with subject mention and a unique index, and commit before realtime.

Wire the register service without changing existing repository fakes or public account DTO. Add message kind to history/search, preserve USER defaults, reject user edits/deletes and system-message replies/attachments, and clear the welcome setting when its channel is archived.

Add deterministic phrase, enabled/disabled/unavailable, rollback, publication-failure and immutable-system-message regression tests.

## Packet 3 — lifecycle signals

Create `observability/guild_lifecycle` span/outcome helpers and bounded `http_metrics` counters. Instrument settings and registration, enrich the successful register HTTP span with server-confirmed NamedAttributes and zero session digest, and emit fixed route/application events. Emit the same bounded counters into OTel for the existing collector. Never record raw errors, passwords, bodies or old/new guild names.

Add trace parent/correlation, bounded cardinality, static route/status and client-OTLP spoofing tests.

## Packet 4 — dashboards, runbook and handoff

Add a session-independent registration/welcome trace panel, lifecycle rates, and a sustained-failure alert excluding normal skips. Document TraceQL/PromQL, committed DB with failed publish and privacy boundaries in the canonical administrator runbook. Record NOT_RUN scoped checks and smoke evidence; do not close the physical acceptance gate.

Inspect exact changed paths/sizes, commit explicitly, create/attach a PR, and merge with `[skip ci]` under the owner's instruction to avoid builds.
