# Client Update Awareness Implementation Plan

**Goal:** Add a public release policy contract, update awareness in the web and Flutter clients, deterministic release metadata, and verified Android and Windows artifacts.

**Route:** `split_first`; each numbered section is one leaf packet with focused tests and native validation before the next packet.

**Product constraints:** One guild per deployment, no media proxying, no automatic native installer, no service worker, no session requirement for public release metadata, and no claim of device acceptance without evidence.

## 1. Contract and release model

- Add a strict JSON Schema for the release catalog and shared evaluator fixtures.
- Extend OpenAPI and the mobile client contract with the public update policy endpoint.
- Add UPD backlog items tied to existing deploy, UI, security, and quality requirements.
- Document the release identity and cache/security behavior.
- Validate contracts and approved-spec traceability.

## 2. Backend catalog service

- Add a bounded catalog parser and selector under a leaf backend capability.
- Keep the last valid in-memory snapshot and reload the configured file every ten seconds.
- Serve only the selected public policy at `GET /api/v1/client-updates` with no-store and nosniff headers.
- Return 400 for invalid selectors and 503 when no valid configured snapshot has ever loaded.
- Add parser, reload, selection, size-limit, and handler tests.

## 3. Release metadata and publishing tools

- Add one committed release metadata document for web and native build identity.
- Generate web build info and Flutter dart defines from that source during native build commands.
- Extend retained artifact manifests with the release identity and source evidence.
- Add a catalog validation/promotion/withdraw command with compare-and-swap revision checks.
- Add unit tests for deterministic generation and catalog mutations.

## 4. Web update client

- Add typed policy parsing and the pure update evaluator with shared fixtures.
- Add recursive foreground scheduling, retry backoff, deduplication, timeout, and stale-result behavior.
- Add a Pinia update store, root-level accessible banner, snooze policy, details view, and manual check.
- Add safe reload checks for draft, upload, pending send, voice, reconnect, and screen-share state.
- Handle Vite preload failures by offering a controlled reload.
- Generate `/build-info.json` and enforce no-store/no-cache/immutable nginx cache rules with explicit asset 404s.
- Add component/store/evaluator/scheduler tests and run web build.

## 5. Flutter update client

- Add package metadata lookup plus compile-time release identity for Android and Windows.
- Add typed policy parsing, the pure evaluator using shared fixture cases, API client, scheduler/controller, snooze storage, lifecycle observer, and action launcher.
- Add a root banner and details/manual-check UI without expanding aggregate state owners.
- Warn before opening an external update action while voice, capture, or pending work is active.
- Add focused Dart tests and run Flutter analysis/tests.

## 6. Deployment and release integration

- Add the read-only catalog mount and explicit backend configuration to deployment compose files.
- Ship a safe initial catalog with web published and unsupported native/store selectors unconfigured until real download URLs are promoted.
- Update release workflows so Android and Windows artifacts retain build identity and release receipts.
- Run deployment/config tests.

## 7. Verification and artifacts

- Run contract and traceability checks, full Go tests, web tests/build, and Flutter analysis/tests.
- Build Android debug APK and Windows release bundle from the updated checkout.
- Record build evidence and a separate `NOT_RUN` physical-device acceptance record.
- Inspect status and changed file sizes, then prepare exact-file commit and delivery handoff.

**Stop condition:** All automated checks pass, Android and Windows artifacts exist with matching release receipts, and any unexecuted physical acceptance work is explicitly recorded without being claimed as passed.
