# User-authored screen-share issues — implementation and acceptance review

- Date: 2026-10-08
- Source base: GitHub `origin/master` at `9b524569bb2b46b95afbb1f5040c32ceefda7214`
- Scope: #145, #146, #148, #157–#162, #164–#170, #172–#175 (20 open issues authored by `Egkurilov`)
- Worktree: `codex/user-authored-issues-next20b-github`.

## Local checks

| Check | Result | Notes |
|---|---|---|
| Web screen-profile browser suite | PASS — 7 passed, 1 skipped | `cd clients/web && npm run test:screen-profile -- --reporter=list`; isolated LiveKit baseline skipped because no test credentials/target were configured. |
| Integrated Web test suite | PASS — 412 files, 1,286 tests | Run from the integrated batch branch after updating the simulcast default expectation and adding explicit opt-in coverage. |
| Descriptor/viewer Web tests | PASS — 7 files, 26 tests | `npm run test -- --run src/voice/screen_profile_metadata src/voice/livekit_screen_registry.spec.ts src/voice/livekit_screen_viewer_metadata.spec.ts` |
| Descriptor Go packages | PASS | `go test ./internal/media/publish_screen_descriptor/... ./internal/app/media_routes/screen_descriptor` from `backend/` |
| Full backend + telemetry contract implementation checks | PASS | `go test ./...`, targeted Go vet, generated contract `--check`, and contract/OpenAPI verifier; performed on tracing gap-fix commit. |
| Web rollout policy implementation checks | PASS | 82 focused Vitest tests, 9 Python image-build tests, contract/OpenAPI verifier, and production build; performed on rollout-flag gap-fix commit. |
| Flutter dependency/import boundary | PASS — 749 files | `python -m tools.verify.dependencies.dart` |
| Flutter focused tests | NOT_RUN | Flutter SDK executable is not installed on this host. Added tests cover platform update notices and #170 sender descriptor parsing/diagnostics. |
| Paired acceptance evidence validator | PASS — 7 tests | `python -m unittest tools.verify.paired_screen_acceptance.test_evidence` |
| Media load matrix planner | PASS — 6 tests | `python -m unittest tools.load.screen_share_matrix.test_planner` |
| Media QoE source contracts | PASS — 6 tests | `python -m unittest tools.verify.media_qoe.test_dashboard` |
| Vue production build | PASS | `VITE_PUBLIC_ORIGIN=https://v.bootybay.ru npm run build`; existing LiveKit import/chunk-size warnings. |
| Full Go backend suite | PASS | `go test ./...` on the integrated batch branch. |
| Contract verifier | PASS — 19 tests | `tools/verify/contracts/verify-contracts.ps1`; OpenAPI 3.1 lint/parity: 89 public operations, 3 private exclusions. |
| Spec traceability verifier | PASS — 39 requirements | `tools/verify/spec_traceability/verify-spec-traceability.ps1`. |
| Combined media source checks | PASS — 24 tests | Paired acceptance, load planner, QoE dashboard, and image-build flag validation tests. |

## Runtime gates

- #158 baseline reports 7 PASS/1 SKIP. Synthetic isolated-SFU run requires short-lived isolated credentials and explicit target confirmation.
- #160 server-authorized descriptor transport is implemented and repository-tested. Cross-client real-SFU attribute round-trip, reconnect/Dynacast race, and physical capture/audio acceptance are `NOT_RUN`.
- #145/#146: telemetry requiredness, owner, string bounds and relay limits now come from the shared contract; malformed overlong fields have tests. Source is committed locally; packaged-client acceptance remains pending.
- #157: bounded simulcast and descriptor metadata have independent Web build flags; simulcast defaults off per catalog. Candidate-image and real SFU negotiation acceptance remain pending.
- #172 has a one-publisher/one-viewer real SDK/SFU smoke and sanitized CI artifact path. Full scenario/fault matrix and dedicated hardware SLO runner are `NOT_RUN`.
- #173 paired evidence JSON remains a template with every pairing `NOT_RUN`; physical device matrix was not run.
- #174 planner defines L01–L10 but is not a media-client generator. Isolated capacity runs and soak are `NOT_RUN`.
- #175 dashboard/alerts and synthetic query fixtures are source-tested. Promtool and deployed Grafana/datasource/alert runtime checks were not run here.
- #166/#167: corrected the Flutter profile dialog so platform-specific source restart behavior is stated accurately; focused tests were added. Native tests remain `NOT_RUN` without Flutter SDK, and automatic capture source restart is not implemented.
- #170: Flutter receiver now reads bounded v1 descriptor metadata, checks deployment origin/account/room and monotonic generation/revision, and presents sender mode/requested profile separately from receiver-measured values. Commits `dc51d854`/`7e10855a`; parser/diagnostic tests are added but remain `NOT_RUN` without Flutter SDK. Device/SFU round-trip acceptance remains pending.
- Docker Desktop Linux engine is unavailable on this host; no local LiveKit/SFU container was started.
- `promtool` and deployed Grafana checks remain `NOT_RUN`; Docker/deployment access was unavailable.

No FPS, latency, quality, load capacity, or deployment result is inferred from unit tests, build output, planner output, or mocks. GitHub issue comments record the exact remaining test environments, per-case `PASS|FAIL|NOT_RUN`, versions, evidence fields, and artifact requirements.
