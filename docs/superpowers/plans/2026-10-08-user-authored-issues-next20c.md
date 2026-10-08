# Next User-Authored Issue Batch Implementation Plan

> **For agentic workers:** Implement only assigned issue scope in a separate worktree. Preserve product/security invariants in `AGENTS.md`; record tests and `PASS|FAIL|NOT_RUN` evidence. Do not push, deploy, or close issues.

**Goal:** Advance the next 20 open BOOHTACORD issues authored by Egkurilov, validate existing implementations, fix repository-owned gaps, and document the remaining acceptance in each issue.

**Architecture:** Keep independent release/update, screen-share transport, tracing, and backend admission changes in separate leaf capabilities. Reuse current ACL, deployment-origin, LiveKit lifecycle, and shared telemetry contracts. Physical/SFU/production gates remain explicitly unproven without their target environments.

**Tech Stack:** Go, Vue 3/TypeScript/Vite, Flutter/Dart, LiveKit, GitHub Actions, Prometheus/Grafana, repository PowerShell/Python/Node verification tools.

---

## Packet and ownership

These 20 currently open, user-authored issues were selected after the prior #145–#175 batch. The already-existing local implementations are included for gap review and acceptance comments; source work is limited to verified gaps.

| Issues | Work package | Owner | Definition of evidence |
|---|---|---|---|
| #223, #133–#139 | Windows update promotion and backend hardening | Agent: audit existing commits/tests; fix only verified gaps | Focused native tests plus old-client/update catalog replay for #223; auth/rate-limit/upload/WebSocket negative and concurrency cases for #133–#139; real deployment stays NOT_RUN. |
| #147, #149–#151 | Web/backend/realtime/outbox user-flow trace continuity | Agent: implementation | Bounded contract/unit tests for action identity, parent/child propagation, reconnect, queue/retry/restart; trace IDs and payloads must not contain prohibited user data. |
| #152–#155, #132 | Media correlation, telemetry reliability, trace acceptance/dashboard, Android QA record | Agent: implementation and evidence audit | Contract/query/source checks plus sanitized synthetic trace; deployed Tempo/Grafana and physical device rows recorded as PASS/FAIL/NOT_RUN with versions/config SHA. |
| #163, #171, #176 | Private screen-preview vertical slice, SFU network diagnostics, staged rollout | Root: implementation/evidence | ACL/generation/size/TTL tests for previews; read-only network/config validator and synthetic path matrix; rollout compatibility/rollback checks. Production/SFU/hardware claims require deployed evidence. |

## Agent A — update catalog and backend hardening (#223, #133–#139)

- Inspect exact existing implementation commits in the dedicated `user-issue-223-updates` and `user-issues-133-139` worktrees; compare each diff to its issue requirements and current `master`.
- Run nearest native tests from the assigned worktree for each capability; record exact command, count, and outcome. Do not treat a prior branch commit or UI-only check as runtime acceptance.
- Fix only reproducible repository-owned gaps. Add regression tests before implementation. Preserve secure-cookie/Origin, trusted-proxy, ACL, upload lifecycle, and bounded concurrency rules.
- Comment on every assigned issue with completed automated checks and explicit required follow-up scenarios, environment, result format, and evidence fields. No issue closure.

## Agent B — flow tracing continuation (#147, #149–#151)

- Route through `backlog/tasks.yaml`, exact observability contract/generator entrypoints, and nearest language-specific tests before changing source.
- For #147, preserve action scope across asynchronous Web operations and prevent stale session/context attribution.
- For #149, carry trusted parent context through backend request/domain stages without adding high-cardinality labels or logging secrets/message content.
- For #150, model realtime cause/delivery/client handling with bounded context and reconnect-safe correlation.
- For #151, preserve safe causality through outbox enqueue, worker retries, and restart; ensure no unbounded trace or serialized sensitive payload.
- Add focused tests first, then run native Go/Web and contract generator/verifier checks required by changed contracts. Write one evidence report and issue comments containing PASS/FAIL/NOT_RUN matrix.

## Agent C — media/tracing gates (#152–#155, #132)

- Route exact telemetry/media sampling, dashboard, CI acceptance, and Android QA paths from the backlog and native manifests.
- Reuse issue owners already assigned to aggregates/retention and screen-share sampling; do not create duplicate exporters, dashboard UIDs, or QA criteria.
- Fix source/query/schema gaps only where verified. Add source/fixture tests; do not fabricate physical or deployed PASS results.
- Record sanitized synthetic validation separately from real relay/Collector/Tempo/Grafana and Android sender/receiver acceptance. Update assigned issues with required environment, scenario matrix, version/config identity, `PASS|FAIL|NOT_RUN`, and artifact fields.

## Root — screen-share delivery and rollout (#163, #171, #176)

- For #163, inspect T-037, the API/store implementation, and Web/Flutter thumbnail lifecycle. Its contract, authorization, bounded JPEG parser/cache, targeted metadata hints, Web/Flutter readers, and client tests already exist in this baseline. Run nearest Go/Web checks, audit each #163 criterion for a source gap, and implement only a proven gap. Keep real database/SFU, physical-client, late-callback, RTP-count, 20-publisher, and multi-process checks `NOT_RUN` without the target environment.
- For #171, inspect the committed LiveKit deployment template and `tools/verify/livekit_network_config`. A repository topology validator, fixed-cardinality metrics contract, private scrape, alert and explicit runtime NOT_RUN evidence already exist. Run the validator/tests and audit for a proven source gap; do not mutate production or infer capacity from a port range. Record target network and SFU gates as NOT_RUN when unavailable.
- For #176, audit existing independent flags and document/validate stage order and rollback compatibility against #157–#175, #155, and release gates. Do not report the epic complete while dependent physical/load/deployment gates are NOT_RUN.
- Run focused Go/Web/Python/contract tests and update local evidence.

## Final integration and comments

- Integrate agent commits into the packet branch after reviewing their diffs and test outputs. Resolve conflicts without dropping behavior.
- Verify `git diff --check`, nearest native tests, `scripts/verify-spec-traceability.ps1` when evidence/backlog requirements change, and `scripts/verify-contracts.ps1` when contracts change (use repository's actual `tools/verify/...` paths if the scripts directory differs).
- Post one clear top-level comment for each of the 20 issues. State which automated checks passed, which required scenarios remain `NOT_RUN`, and what exact device/SFU/deployment/evidence form is expected. Update an existing task comment instead of duplicating it when appropriate.
- Keep all issue states open until their own acceptance gates are met. After review and native verification, fast-forward the local `master` worktree to this packet branch as the user requested. Do not push or deploy.
