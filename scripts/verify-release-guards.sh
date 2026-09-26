#!/usr/bin/env bash
set -euo pipefail

bash scripts/install-ci-powershell.sh
compose_cli="$(bash scripts/install-ci-compose.sh)"
trap 'rm -f "$compose_cli"' EXIT
export VOICE_PLATFORM_COMPOSE_CLI="$compose_cli"
pwsh -NoProfile -File scripts/verify-contracts.ps1
pwsh -NoProfile -File scripts/verify-spec-traceability.ps1
pwsh -NoProfile -File scripts/verify-ci-sbom.ps1
pwsh -NoProfile -File scripts/verify-android-release-signing.ps1
printf 'Checking Compose configuration...\n'
"$compose_cli" --env-file .env.example -f compose.yaml --profile operator config --quiet
printf 'Checking Compose image contract...\n'
pwsh -NoProfile -File scripts/verify-compose-images.ps1
bash scripts/check-attachment-volume-headroom.test.sh
bash scripts/audit-attachment-volume.test.sh
bash scripts/qa11_release/preflight.test.sh
python3 scripts/qa11_release/verify_oci.test.py
bash scripts/qa11_release/verify_running.test.sh
bash scripts/deploy-images.test.sh
bash scripts/deploy-images-volume-guard.test.sh
bash scripts/deploy-images-rollback.test.sh
bash scripts/qa12_rollback/preflight.test.sh
bash scripts/qa12_rollback/rehearse.test.sh
bash scripts/qa12_rollback/workflow.test.sh
bash scripts/deploy-local-images.test.sh
bash scripts/resume_built_release/resume.test.sh
bash scripts/qa08_capacity/reclaim_old_images.test.sh
bash scripts/qa08_capacity/prune_build_cache.test.sh
