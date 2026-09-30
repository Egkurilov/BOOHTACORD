# Test model review implementation plan

> **For agentic workers:** Execute these bounded packets inline, with native checks after each packet.

**Goal:** Make the test gates cover the app and its forked media packages before merge, and record remaining platform limits.

**Architecture:** Preserve the existing Go, Vitest, and Flutter suites. Run the local Flutter package suites explicitly, then add a hosted Flutter gate to pull requests and master. Keep Windows and macOS build jobs for their native artifacts.

**Tech Stack:** Go, PostgreSQL, Vitest, Flutter, GitHub Actions, PowerShell.

---

## Operating brief

- workflow_class=review_gate; task_size=large; structure_mode=structure_no_rg; search_stage=selected-leaf.
- route=T-060 release quality gates. Doctrine: preserve behavior, use native test evidence, keep release claims bounded by actual platform checks.
- Ratchet: new files target 100/hard 120 lines; one independent trigger family per leaf; avoid edits in existing large upstream tests.
- Search boundary: CI manifests, Flutter package test entrypoints, package fixture path, Go test event gate, nearest telemetry and media tests.
- Exact edges: `ci.yaml` → reusable jobs; `desktop/pubspec.yaml` → app suite; package pubspecs → local media suites; `testfiles/` → stream fixture writes.
- Native checks: Go suite, Vitest, Flutter app and package suites, Flutter analyze, Android debug build, workflow contract verifier.
- Stop: CI runs app and media package tests before merge, Android compilation is gated, fixture suites pass, and platform limitations are recorded.
- Open: iOS native build needs a macOS runner and device media quality needs physical two-client acceptance.

## Packet 1 — baseline and package fixture

- [x] Count tracked Go, web, app Flutter and fork package tests; inspect CI triggers and skipped tests.
- [x] Run existing suites separately. Baseline: Go and web pass; Flutter app passes; WebRTC package passes; LiveKit has three missing-directory failures and one skipped upstream test.
- [x] Add a tracked empty `desktop/packages/livekit_client/testfiles/` fixture directory with ignore rules for generated test files.
- [x] Route standalone LiveKit tests to the local WebRTC fork through its package manifest.
- [x] Re-run both failing LiveKit files, then the complete LiveKit and WebRTC package suites.

## Packet 2 — pull-request Flutter gate

- [x] Extend `scripts/verify-github-workflows.ps1` so it fails when CI lacks a Flutter job that tests app and local media packages and compiles Android debug.
- [x] Run the verifier and confirm the new assertion fails against the baseline CI configuration.
- [x] Add `.github/workflows/ci-flutter.yaml` with hosted Flutter 3.47.5, locked app dependencies, app tests, package tests, analysis and Android debug compile.
- [x] Make `.github/workflows/ci.yaml` call the Flutter job on pull requests and master; rerun the verifier.
- [x] Make Android tag releases wait for the same Flutter gate before signing or publishing.

## Packet 2b — telemetry failure behavior

- [x] Add a web timer test for hidden views, overlapping delivery and disposal in `frontend/src/telemetry/report_media/interval.spec.ts`.
- [x] Add a Flutter test for an in-flight report that fails, then verify reporting resumes after the interval in `desktop/test/user_media_telemetry_test.dart`.
- [x] Add a Go test proving unauthenticated media samples never create a trace in `backend/internal/observability/report_client_screen/api/media_sample_test.go`.
- [x] Run each nearest native test before the full suites.

## Packet 2c — OTLP exporter smoke tests

- [x] Add an in-process HTTP receiver test in `backend/internal/observability/start_tracing/provider_test.go` that observes a real exported span and the ingest authorization header.
- [x] Add an in-process HTTP receiver test in `backend/internal/observability/start_metrics/provider_test.go` that forces a metric flush and observes the export.
- [x] Confirm both exporters are no-ops when endpoint configuration is absent, then run the nearest Go packages.

## Packet 2d — portable Flutter notification tests

- [x] Use the failing Linux CI result to identify three notification-service tests and one profile-widget test tied to the host platform.
- [x] Allow `NativeNotificationService` to receive an explicit supported-platform decision in tests while preserving the production default.
- [x] Inject that decision in the four affected tests, rerun them locally, then rerun the hosted Flutter gate.

## Packet 3 — review and delivery

- [x] Document coverage and test-model findings in `docs/reviews/2026-10-01-test-model.md`, distinguishing unit, database integration, build and physical-device gates.
- [x] Record a T-060 evidence result under `evidence/release/`, with `NOT_RUN` for unavailable iOS/device checks.
- [x] Run native checks, inspect status and file sizes, stage exact files, commit and push the review branch.
- [x] Check GitHub CI on the branch or PR; PR CI run `36788582014` passed before merge.
