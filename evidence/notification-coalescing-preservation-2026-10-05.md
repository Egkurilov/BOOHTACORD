# Notification preservation during protected refresh coalescing

Date: 2026-10-05. Executor: Codex; isolated local Web validation.
Scope: issue #80; actual workspace dispatch and protected refresh batch handler.

Before the fix, three created DM hints in one batch captured unread state three
times and attempted three notifications against the same refresh result.
The focused regression failed with actual capture count 3, expected 1.

The batch now captures/delivers one created notification per resource, preserving
every protected refresh event. TEXT and DM namespaces remain independent.
Failure propagation remains available to the durable replay controller.

Results:
- Focused workspace/protected refresh tests: 18 tests / 5 files PASS.
- Full Web: 1128 tests / 355 files PASS, Node 24.18.0, Vitest 5.0.1.
- TypeScript and Vite production build: PASS.
- Regression coverage: duplicate scope, distinct TEXT/DM scopes, failure replay.
- Git Web source tree: `82e2ebde1d97f7be6cf443095e1af751431c907d`.

This record supersedes the prior Web test count for the new source tree.
Earlier actual browser/CI receipts identify their own revisions; final CI and
actual acceptance for this tree are tracked in PR #128. OS notification/device
acceptance QA-03 remains NOT_RUN; these assertions do not close that broader gate.
