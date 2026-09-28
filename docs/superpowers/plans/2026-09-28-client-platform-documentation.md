# Client platform documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give web, Android and future iOS development separate, accurate entry points without disrupting existing build roots.

**Architecture:** `clients/` owns platform navigation and iOS preparation; `frontend/` and `desktop/` remain canonical source/build roots. Root and Flutter README files link to these entries, while version facts come from native manifests.

**Tech Stack:** Markdown, Vue 3/TypeScript/Vite, Flutter/Dart, Go API, LiveKit.

---

### Task 1: Map platform roots and versions

**Files:** `clients/README.md`, `docs/CLIENT_VERSIONING.md`

- [x] Confirm `frontend/package.json` declares `0.1.0`, `desktop/pubspec.yaml` declares `1.0.0+1`, and `desktop/ios/` is absent at commit `13aeb3e`.
- [x] Write a source-of-truth table and distinguish package metadata from verified release status.

### Task 2: Give each client its own entry point

**Files:** `clients/web/README.md`, `clients/android/README.md`, `clients/ios/README.md`

- [x] Document exact source, runner, native commands, implemented capabilities and evidence limits for each platform.
- [x] Preserve `frontend/` and `desktop/` paths used by production delivery and Android release checks.

### Task 3: Prepare iOS implementation

**Files:** `clients/ios/DEVELOPMENT.md`, `clients/ios/ACCEPTANCE.md`

- [x] Define the macOS/Xcode bootstrap, security and API/voice/screen-sharing integration work.
- [x] Define physical-device, privacy, media and release evidence required before claiming iOS parity.

### Task 4: Refresh navigation and verify documentation

**Files:** `README.md`, `desktop/README.md`

- [x] Link platform sections, version policy and the existing parity/evidence sources.
- [x] Replace outdated Flutter feature exclusions with a truthful source-implemented versus device-verified split.
- [x] Check relative links and `git diff --check`, then run `scripts/verify-spec-traceability.ps1`.
