# CI SBOM Attestations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Attach an SBOM to each immutable API and web image published by main-branch CI, while continuing to deploy digest-qualified references only.

**Architecture:** The existing `docker/build-push-action@v6` build steps receive the documented `sbom: true` input, which asks Buildx to generate an OCI SBOM attestation alongside each pushed image. A PowerShell static contract checks both publisher steps and the digest handoff without requiring GitHub credentials or publishing an image locally.

**Tech Stack:** GitHub Actions YAML, Docker Buildx attestation input, PowerShell static verification.

---

### Task 1: Specify the immutable SBOM CI contract

**Files:**
- Create: `scripts/verify-ci-sbom.ps1`
- Test: `scripts/verify-ci-sbom.ps1`

- [x] **Step 1: Write the verifier that requires both publisher blocks to contain an SBOM input.**

```powershell
foreach ($name in @('API', 'web')) {
    $step = [regex]::Match($workflow, "(?ms)^      - name: Build and push $name image\r?\n(?<body>.*?)(?=^      - name:|^  deploy:)")
    if (-not $step.Success -or $step.Groups['body'].Value -notmatch '(?m)^          sbom: true$') {
        throw "$name publisher must request an SBOM attestation."
    }
}
```

- [x] **Step 2: Require SHA tags, pushed images, and digest-qualified deployment outputs.**

```powershell
foreach ($step in $publisherSteps) {
    if ($step -notmatch '(?m)^          push: true$' -or $step -notmatch 'github\.sha') {
        throw 'Publisher must push a commit-SHA image.'
    }
}
if ($workflow -notmatch 'voice-platform-api@\$\{\{ steps\.api-image\.outputs\.digest \}\}') {
    throw 'API release output must be digest-qualified.'
}
```

- [x] **Step 3: Run the verifier before the workflow change.**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-ci-sbom.ps1`

Expected: failure naming the first publisher without an SBOM attestation.

### Task 2: Attach SBOMs to both published images

**Files:**
- Modify: `.github/workflows/ci.yml:65-89`
- Test: `scripts/verify-ci-sbom.ps1`

- [x] **Step 1: Add the documented Buildx input to the API publisher.**

```yaml
      - name: Build and push API image
        uses: docker/build-push-action@v6
        with:
          context: ./backend
          push: true
          sbom: true
          tags: ghcr.io/${{ github.repository_owner }}/voice-platform-api:${{ github.sha }}
```

- [x] **Step 2: Add the same input to the web publisher.**

```yaml
      - name: Build and push web image
        uses: docker/build-push-action@v6
        with:
          context: ./frontend
          push: true
          sbom: true
          tags: ghcr.io/${{ github.repository_owner }}/voice-platform-web:${{ github.sha }}
```

- [x] **Step 3: Run the verifier and require success.**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-ci-sbom.ps1`

Expected: `CI SBOM contract: OK`.

### Task 3: Validate without publishing an image

**Files:**
- Validate: `.github/workflows/ci.yml`
- Validate: `scripts/verify-ci-sbom.ps1`

- [x] **Step 1: Run the existing contracts and new SBOM contract.**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-contracts.ps1` and `powershell -ExecutionPolicy Bypass -File scripts/verify-ci-sbom.ps1`.

Expected: both commands succeed.

- [x] **Step 2: Inspect the packet without staging or triggering CI.**

Run: `git diff --check -- .github/workflows/ci.yml scripts/verify-ci-sbom.ps1` and `git status --short -- .github/workflows/ci.yml scripts/verify-ci-sbom.ps1`.

Expected: no diff errors. Do not stage, push, publish, or deploy from this shared dirty worktree.
