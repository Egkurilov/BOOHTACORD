# Build artifact storage implementation plan

> Execute in the existing managed worktree, one bounded packet at a time.

**Goal:** Keep generated binaries out of Git and make CI desktop builds downloadable as GitHub Actions artifacts.

**Architecture:** Treat Git as the source repository. Keep build inputs such as app icons; publish Windows CI output as a complete directory artifact and macOS CI output as the already validated ZIP plus checksum. Existing signed release files remain in GitHub Releases.

**Tech stack:** Git, GitHub Actions, PowerShell, Flutter, macOS release packaging.

## Operating brief

- workflow_class=split_first; task_size=medium; structure_mode=structure_no_rg; search_stage=selected-leaf.
- route=T-054 delivery outputs, with T-060 release checks. Active doctrine: preserve builds and release semantics; do not rewrite shared Git history.
- Ratchet: new files target 100/hard 120 lines, leaf target 8/hard 16 production files and direct tests.
- Scoped boundary: `.gitignore`, `.github/workflows/flutter-windows.yaml`, `flutter-macos.yaml`, `android-release.yaml`, `macos-release.yaml`, `scripts/verify-github-workflows.ps1`, artifact docs and release evidence.
- Exact edges: Flutter build output → CI upload; macOS `package.sh` → ZIP/checksum → CI upload; release tag → GitHub Release assets. Native checks: workflow verifier, macOS package test, GitHub Windows CI artifact listing, production CI contracts.
- Baseline: GitHub `origin/master` and all 17 remote tags have zero historical blobs above 1 MB. Local GitVerse refs retain old binaries; current `master` tracks only needed binary assets such as app icons. Windows and manual macOS CI currently build without uploading files.
- Stop: tracked generated files are rejected, workflows upload complete builds, at least Windows artifact is visible/downloadable from a successful GitHub run. macOS runner absence is recorded as NOT_RUN.

## Packet 1 — guard generated outputs

- [x] Extend the existing GitHub workflow verifier to fail for tracked build archives and missing CI artifact publication. Run it first to see the missing publication fail.
- [x] Ignore generated archives under `artifacts/` and Python bytecode caches; retain tracked source assets.
- [x] Run the verifier again after CI wiring.

## Packet 2 — publish CI builds

- [x] Upload the entire Windows `Release` directory after a successful build, with a clear artifact name, 30-day retention and a missing-files failure.
- [x] Reuse the tested macOS release packager for manual CI; upload its ZIP and checksum with the same failure and retention policy.
- [x] Document where to download CI artifacts, where durable signed releases live, and the limits of old local GitVerse refs.

## Packet 3 — delivery and evidence

- [ ] Inspect status and sizes, stage exact files, commit on `codex/artifact-storage`, integrate current GitHub `master` and push.
- [ ] Wait for CI/Windows CI and inspect uploaded artifact contents, including the EXE, DLL and Flutter assets.
- [ ] Record verification evidence and limits; keep physical/macOS checks open if their runners are unavailable.
