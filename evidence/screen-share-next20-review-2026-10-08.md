# User-authored screen-share issues — implementation and acceptance review

- Date: 2026-10-08
- Source base: GitHub `origin/master` at `9b524569bb2b46b95afbb1f5040c32ceefda7214`
- Scope: #145, #146, #148, #157–#162, #164–#170, #172–#175 (20 open issues authored by `Egkurilov`)
- Worktree: `codex/user-authored-issues-next20b-github`; no application source changed in this review.

## Local checks

| Check | Result | Notes |
|---|---|---|
| Web screen-profile browser suite | PASS — 7 passed, 1 skipped | `cd clients/web && npm run test:screen-profile -- --reporter=list`; isolated LiveKit baseline skipped because no test credentials/target were configured. |
| Descriptor/viewer Web tests | PASS — 7 files, 26 tests | `npm run test -- --run src/voice/screen_profile_metadata src/voice/livekit_screen_registry.spec.ts src/voice/livekit_screen_viewer_metadata.spec.ts` |
| Descriptor Go packages | PASS | `go test ./internal/media/publish_screen_descriptor/... ./internal/app/media_routes/screen_descriptor` from `backend/` |
| Paired acceptance evidence validator | PASS — 7 tests | `python -m unittest tools.verify.paired_screen_acceptance.test_evidence` |
| Media load matrix planner | PASS — 6 tests | `python -m unittest tools.load.screen_share_matrix.test_planner` |
| Media QoE source contracts | PASS — 6 tests | `python -m unittest tools.verify.media_qoe.test_dashboard` |
| Vue production build | PASS | `VITE_PUBLIC_ORIGIN=https://v.bootybay.ru npm run build`; existing LiveKit import/chunk-size warnings. |

## Runtime gates

- #158 baseline reports 7 PASS/1 SKIP. Synthetic isolated-SFU run requires short-lived isolated credentials and explicit target confirmation.
- #160 server-authorized descriptor transport is implemented and repository-tested. Cross-client real-SFU attribute round-trip, reconnect/Dynacast race, and physical capture/audio acceptance are `NOT_RUN`.
- #172 has a one-publisher/one-viewer real SDK/SFU smoke and sanitized CI artifact path. Full scenario/fault matrix and dedicated hardware SLO runner are `NOT_RUN`.
- #173 paired evidence JSON remains a template with every pairing `NOT_RUN`; physical device matrix was not run.
- #174 planner defines L01–L10 but is not a media-client generator. Isolated capacity runs and soak are `NOT_RUN`.
- #175 dashboard/alerts and synthetic query fixtures are source-tested. Promtool and deployed Grafana/datasource/alert runtime checks were not run here.
- Docker Desktop Linux engine is unavailable on this host; no local LiveKit/SFU container was started.

No FPS, latency, quality, load capacity, or deployment result is inferred from unit tests, build output, planner output, or mocks. GitHub issue comments record the exact remaining test environments, per-case `PASS|FAIL|NOT_RUN`, versions, evidence fields, and artifact requirements.
