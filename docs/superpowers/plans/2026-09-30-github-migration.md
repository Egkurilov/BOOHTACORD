# GitHub Migration Implementation Plan

> **For agentic workers:** Execute the checked steps in this session. Keep the production release path guarded until GitHub runner and secret evidence is available.

**Goal:** Make GitHub `master` the repository and Actions source for CI, releases, and production delivery.

**Architecture:** Fetch GitVerse `master` first, then migrate each existing workflow without changing its release script semantics. Use GitHub `GITHUB_TOKEN` for release publication and retain the guarded SSH delivery path. Record the change to ADR-010 in a successor ADR.

**Tech Stack:** Git, GitHub Actions, PowerShell, Bash, Node.js, Go, Vue, Flutter, Docker Compose.

---

### Task 1: Repository and CI routing

- [x] Fetch GitVerse `master` and advance the local branch by fast forward.
- [x] Move the nine GitVerse workflows into `.github/workflows` and change contexts, output files, permissions, and runner labels to GitHub equivalents.
- [x] Keep one production writer and make the existing GHCR publisher run on `master`.
- [x] Point source-contract tests at the GitHub workflow paths and run them.

### Task 2: Client releases

- [x] Port the Android release publisher to the GitHub Releases API with its existing retry and asset-conflict tests.
- [x] Use GitHub Releases for macOS and point Windows CI at the supported release publisher test.
- [x] Run the publisher tests; macOS packaging remains pending a macOS runner.

### Task 3: Operations and handoff

- [x] Supersede ADR-010 and update active operator/release docs and required GitHub runner, secret, and environment setup.
- [x] Run the nearest release guards and spec/contract validation where applicable.
- [x] Inspect changed file sizes, commit the migration, set the shared Git remote to GitHub, and publish rewritten `master` and release tags.
- [ ] Register self-hosted runners and transfer secrets from the owner-controlled stores; then verify trusted GitHub CI, deploy and client release runs.
