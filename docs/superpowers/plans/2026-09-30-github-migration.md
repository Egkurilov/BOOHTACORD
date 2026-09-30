# GitHub Migration Implementation Plan

> **For agentic workers:** Execute the checked steps in this session. Keep the production release path guarded until GitHub runner and secret evidence is available.

**Goal:** Make GitHub `master` the repository and Actions source for CI, releases, and production delivery.

**Architecture:** Fetch GitVerse `master` first, then migrate each existing workflow without changing its release script semantics. Use GitHub `GITHUB_TOKEN` for release publication and retain the guarded SSH delivery path. Record the change to ADR-010 in a successor ADR.

**Tech Stack:** Git, GitHub Actions, PowerShell, Bash, Node.js, Go, Vue, Flutter, Docker Compose.

---

### Task 1: Repository and CI routing

- [x] Fetch GitVerse `master` and advance the local branch by fast forward.
- [ ] Move the nine GitVerse workflows into `.github/workflows` and change contexts, output files, permissions, and runner labels to GitHub equivalents.
- [ ] Keep one production writer and make the existing GHCR publisher run on `master`.
- [ ] Point source-contract tests at the GitHub workflow paths and run them.

### Task 2: Client releases

- [ ] Port the Android release publisher to the GitHub Releases API with its existing retry and asset-conflict tests.
- [ ] Use GitHub Releases for macOS and point Windows CI at the supported release publisher test.
- [ ] Run the publisher and packaging tests.

### Task 3: Operations and handoff

- [ ] Supersede ADR-010 and update active operator/release docs and required GitHub runner, secret, and environment setup.
- [ ] Run the nearest release guards and spec/contract validation where applicable.
- [ ] Inspect changed file sizes, commit on `codex/github-migration`, switch the shared Git remote to GitHub, and push the migration branch when authentication permits.
