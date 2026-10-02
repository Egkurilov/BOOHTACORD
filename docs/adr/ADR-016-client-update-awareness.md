# ADR-016: Client update awareness

Status: accepted for implementation on 2026-10-02.

## Decision

The API serves public, metadata-only update policy from a bounded JSON catalog at
`GET /api/v1/client-updates`. The selector is application family, platform,
distribution, channel and architecture. The API keeps the last valid in-memory
snapshot and never makes the rest of the service unavailable because a catalog
reload failed.

Web identity is compiled into the JavaScript bundle and emitted separately as
`/build-info.json`. Native identity combines compile-time release ID/order with
installed package version/build. The committed `contracts/client-build.json`
contains independent web, Android, iOS, Windows and macOS lines. Each build path
selects one line and copies its selector and identity into the bundle and
retained release receipt. Web has no native package build number.

Clients evaluate policy locally using the same language-neutral fixtures. They
check after a short startup jitter, every five foreground minutes, on a stale
resume, and on explicit user request. Network errors preserve the previous
successful result while marking it stale.

Web offers a controlled reload. Android and Windows open the exact external
download page only after a user action. No client installs a package, closes an
active media session, discards a draft, or reloads automatically.

The deployment mounts the catalog read-only. Promotion and withdrawal use an
atomic compare-and-swap revision command with a single-publisher lock and
durable temporary-file flush. Store-only selectors remain
`unconfigured` until an actual distribution URL exists.

Catalog revision reuse with different bytes and revision rollback are rejected.
The existing Prometheus registry exposes bounded update-check and catalog-load
health without release IDs, user IDs or URLs as labels.

## Consequences

The first deployment teaches clients how to discover later releases. Physical
A/B acceptance still needs two real releases and target devices; automated
build success cannot close that gate.
