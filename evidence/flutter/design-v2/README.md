# Flutter Design V2 evidence index

This directory tracks acceptance evidence for backlog task FV2-006: responsive,
accessibility, and Android/macOS/Windows platform acceptance for Flutter Design
V2.

**Status: NOT_RUN.** The implementation and platform acceptance have not been
completed. This index only makes the planned evidence location explicit; it is
not a pass result and does not close FV2-006 or any release gate.

The implementation plan is in
[`docs/superpowers/plans/2026-10-03-design-v2-flutter.md`](../../../docs/superpowers/plans/2026-10-03-design-v2-flutter.md).
Add dated evidence records here as each acceptance run is performed, including
the source revision, platform/device, scenario, commands, result, and limits.

The administrator parity implementation is tracked in
[`qa-admin-parity-2026-10-07-001.json`](../qa-admin-parity-2026-10-07-001.json).
It records the focused Flutter evidence and explicitly leaves unavailable
platform runtime acceptance as `NOT_RUN`; it does not close FV2-006.

## Administration parity follow-up — 2026-10-07

The dedicated branch `codex/issue-188-flutter-admin-completion` now records
responsive Members rows and a Roles before/current/proposed conflict review.
The full Flutter suite passed 791 tests (one expected skip), the changed admin
files analyze cleanly, the dependency guard passed, and version `1.0.38+71`
split APKs were built. Details are in
[`qa-admin-members-responsive-2026-10-07-001.json`](../qa-admin-members-responsive-2026-10-07-001.json)
and
[`qa-admin-roles-conflict-2026-10-07-001.json`](../qa-admin-roles-conflict-2026-10-07-001.json).
These are implementation results; native Android/macOS/iOS/Windows runtime
acceptance remains open under #198. ADB was unavailable during this run.

## macOS admin runtime — 2026-10-07

The native macOS client rendered the complete administrator section set at
`2048x1340`: Guild, Members, Roles, Channels, Audit, Media and Readiness. The
accessibility tree exposed the expected filters, forms, permission controls,
member actions, freshness state and readiness status. This is recorded in
[`qa-admin-macos-runtime-2026-10-07-001.json`](../qa-admin-macos-runtime-2026-10-07-001.json).
It is a macOS admin-surface pass only; live resize and the Android/iOS/Windows
runtime matrix remain open under #198.
