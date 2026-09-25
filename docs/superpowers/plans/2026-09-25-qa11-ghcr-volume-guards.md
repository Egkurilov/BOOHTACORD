# QA-11 GHCR volume guards implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the approved GitHub `main` → GHCR deployment check the exact attachment volume before mutation, after image pull and after rollout.

**Architecture:** Reuse the existing production headroom guard and API/metric audit. The SSH job stages those scripts with the release, invokes the first guard before installing files, and audits the digest-qualified running image after `deploy-images.sh`; the deploy script checks headroom again after pulling images and before changing `.env` or running migration.

**Tech Stack:** GitHub Actions YAML, Bash, Docker Compose, fake-Docker release tests.

---

### Task 1: Audit a digest-qualified API image

**Files:** Modify `scripts/audit-attachment-volume.sh` and `scripts/audit-attachment-volume.test.sh`.

- [x] Extend the fixture runner to pass an optional expected image reference; add a passing `ghcr.io/example/voice-platform-api@sha256:` followed by 64 lowercase hex characters, and failures for the wrong running image and malformed digest.
- [x] Run `bash scripts/audit-attachment-volume.test.sh`; the new valid-digest case failed before implementation.
- [x] Parse exactly one of the existing 40-character local Git SHA or `ghcr.io/<owner>/voice-platform-api@sha256:<64 lowercase hex>` and compare the running container image with that exact reference:

  ```bash
  if [[ ${1:-} =~ ^[0-9a-f]{40}$ ]]; then
    expected_image="voice-platform-api:$1"
  elif [[ ${1:-} =~ ^ghcr[.]io/[a-z0-9][a-z0-9-]*/voice-platform-api@sha256:[0-9a-f]{64}$ ]]; then
    expected_image="$1"
  else
    fail 'expected deployed API revision or GHCR digest is invalid'
  fi
  ```

- [x] Rerun the focused test and `shellcheck` on both files; both passed.

### Task 2: Guard capacity after registry pull

**Files:** Modify `scripts/deploy-images.sh` and `scripts/deploy-images.test.sh`.

- [x] Add a fixture guard at `<project>/scripts/check-attachment-volume-headroom.sh` that logs a call and can fail under a test flag. Assert `pull api migrate web` precedes that call, and that failure prevents `.env` replacement, migration and workload switch while maintenance admission is disabled in cleanup.
- [x] Run `bash scripts/deploy-images-volume-guard.test.sh`; the new failure assertion failed before implementation.
- [x] Invoke the project-owned guard immediately after registry image pull and before writing the release `.env`:

  ```bash
  if [[ "$release_mode" == "registry-digest" ]]; then
    API_IMAGE="$api_image" WEB_IMAGE="$web_image" "${compose[@]}" pull api migrate web
  fi
  bash "$project_dir/scripts/check-attachment-volume-headroom.sh"
  ```

- [x] Rerun deploy tests and shellcheck; both passed.

### Task 3: Connect the approved SSH workflow

**Files:** Modify `.github/workflows/ci.yml`.

- [x] Stage `scripts/check-attachment-volume-headroom.sh` and `scripts/audit-attachment-volume.sh` alongside Compose/Caddy/deploy script; run the guard from the staged copy before installing release files.
- [x] Install both scripts with the release, call `deploy-images.sh` with digest refs, then run the audit with the exact API digest ref:

  ```bash
  sudo bash "$staging/check-attachment-volume-headroom.sh"
  sudo install -m 0755 "$staging/check-attachment-volume-headroom.sh" /opt/voice-platform/scripts/check-attachment-volume-headroom.sh
  sudo install -m 0755 "$staging/audit-attachment-volume.sh" /opt/voice-platform/scripts/audit-attachment-volume.sh
  sudo env API_IMAGE="$API_IMAGE" WEB_IMAGE="$WEB_IMAGE" /opt/voice-platform/scripts/deploy-images.sh
  bash "$staging/audit-attachment-volume.sh" "$API_IMAGE"
  ```

- [x] YAML, pinned `actionlint` v1.7.12, `bash scripts/verify-release-guards.sh`, and Windows approved-brief traceability passed. Inspect status, diff and changed file lengths before staging.

The GitHub repository is currently inaccessible to this checkout, so a trusted GitHub run and GHCR attestations remain separate QA-11 acceptance evidence. This plan does not choose a replacement delivery ADR or claim the release gate complete.
