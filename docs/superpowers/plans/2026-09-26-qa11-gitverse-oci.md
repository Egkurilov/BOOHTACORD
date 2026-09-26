# QA-11 GitVerse OCI Delivery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bind each GitVerse `master` release to retained API/web OCI digests, SBOM, provenance, exact source revision, and running containers.

**Architecture:** Package tracked commit bytes with `git archive`; transfer a checksum-pinned Buildx binary separately. Build API and web once each with OCI and local Docker outputs, verify the descriptor graph and image identity, then run the existing guarded deployment and compare running containers with the verified digests. Retain both OCI archives and a release receipt under the revision directory.

**Tech Stack:** GitVerse CI, Bash, Docker Buildx, OCI image layout, Python standard library.

---

### Task 1: Verify OCI export

**Files:** Create `scripts/qa11_release/verify_oci.py`, `scripts/qa11_release/verify_oci.test.py`; modify `scripts/verify-release-guards.sh`.

- [ ] Write a test fixture with nested OCI index, runnable linux/amd64 manifest, attestation manifest, SPDX and SLSA statements; require the expected revision and source archive hash labels, descriptor hashes and sizes, and expected loaded image ID.
- [ ] Run `python scripts/qa11_release/verify_oci.test.py`; observe a missing implementation failure.
- [ ] Implement read-only tar inspection that rejects any missing/mismatched descriptor, wrong attestation subject, absent SBOM/provenance, or mismatched runtime ID and prints a JSON receipt.
- [ ] Run the focused test and release guard; commit the verifier and test.

### Task 2: Build and retain images

**Files:** Create `scripts/qa11_release/build_images.sh`, `scripts/qa11_release/transfer_release.sh`; modify `scripts/install-received-release.sh`, `.gitverse/workflows/deploy-production.yaml`.

- [ ] Add shell tests with fake Docker for checksum rejection, free-space guard and build failure before rollout; run them and observe failure.
- [ ] Change the GitVerse source package to `git archive` and transfer pinned Buildx v0.37.1 separately; verify its SHA-256 before installation in temporary Docker config.
- [ ] Build API and web with revision/source-hash labels, `--sbom=true`, `--provenance=mode=max`, OCI archive and `--load`; enforce attachment headroom before and between exports, verify both archives, retain receipts.
- [ ] Run shell tests and native release guards, then commit.

### Task 3: Prove deployment identity

**Files:** Modify `scripts/deploy-images.sh` or add a QA-11 post-rollout verifier; update `TODO.md`, `backlog/VERIFICATION_TODO.md`, `docs/release/2026-09-25-requirements-matrix.md`; create `evidence/release/qa11-gitverse-oci-2026-09-26-001.json`.

- [ ] Add a test that detects swapped tags or running-container image IDs and rejects the release.
- [ ] Check image ID against the OCI index before rollout and running API/web container `.Image` afterward; keep existing health and volume gates.
- [ ] Run focused tests, release guards, and trusted branch CI. Push and merge to GitVerse `master`, inspect the exact master run, health, digests, and retained attestations.
- [ ] Record truthful PASS/PARTIAL evidence and update TODO only after observing the trusted release.
