#!/usr/bin/env bash
set -euo pipefail

python3 -m venv .out/release-guards-venv
source .out/release-guards-venv/bin/activate
python -m pip install -r tools/requirements-ci.txt

bash tools/ci/powershell/install-ci-powershell.sh
compose_cli="$(bash tools/ci/compose/install-ci-compose.sh)"
trap 'rm -f "$compose_cli"' EXIT
export VOICE_PLATFORM_COMPOSE_CLI="$compose_cli"
pwsh -NoProfile -File tools/verify/contracts/verify-contracts.ps1
pwsh -NoProfile -File tools/verify/spec_traceability/verify-spec-traceability.ps1
pwsh -NoProfile -File tools/verify/ci_sbom/verify-ci-sbom.ps1
pwsh -NoProfile -File tools/verify/github_workflows/verify-github-workflows.ps1
pwsh -NoProfile -File tools/verify/android_release_signing/verify-android-release-signing.ps1
printf 'Checking Compose configuration...\n'
"$compose_cli" --env-file .env.example -f deploy/compose.yaml --profile operator config --quiet
pwsh -NoProfile -File tools/verify/otel_egress/verify-otel-egress.ps1
python3 -m unittest tools.verify.trace_dashboard.test_traces_dashboard
printf 'Checking Compose image contract...\n'
pwsh -NoProfile -File tools/verify/compose_images/verify-compose-images.ps1
bash tools/ops/attachment_headroom/check-attachment-volume-headroom.test.sh
bash tools/ops/attachment_audit/audit-attachment-volume.test.sh
bash tools/qa/active_uploads/sample_active_uploads.test.sh
bash tools/release/preflight/preflight.test.sh
python3 tools/verify/oci/test_verify_oci.py
bash tools/verify/running_images/verify_running.test.sh
bash tools/release/rollout/deploy-images.test.sh
bash tools/release/rollout/deploy-images-volume-guard.test.sh
bash tools/release/rollout/deploy-images-rollback.test.sh
bash tools/qa/legacy_rollback/image_ref.test.sh
bash tools/qa/legacy_rollback/preflight.test.sh
bash tools/qa/legacy_rollback/rehearse.test.sh
bash tools/qa/legacy_rollback/workflow.test.sh
bash tools/release/legacy_install/deploy-local-images.test.sh
bash tools/release/legacy_resume/resume.test.sh
bash tools/ops/docker_storage/reclaim_old_images.test.sh
bash tools/ops/docker_storage/prune_build_cache.test.sh
bash tools/ops/docker_storage/reclaim_deploy_headroom.test.sh
