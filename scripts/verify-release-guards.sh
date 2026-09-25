#!/usr/bin/env bash
set -euo pipefail

bash scripts/install-ci-powershell.sh
compose_cli="$(bash scripts/install-ci-compose.sh)"
trap 'rm -f "$compose_cli"' EXIT
export VOICE_PLATFORM_COMPOSE_CLI="$compose_cli"
pwsh -NoProfile -File scripts/verify-contracts.ps1
pwsh -NoProfile -File scripts/verify-spec-traceability.ps1
"$compose_cli" --env-file .env.example -f compose.yaml --profile operator config --quiet
pwsh -NoProfile -File scripts/verify-compose-images.ps1
bash scripts/check-attachment-volume-headroom.test.sh
bash scripts/deploy-images.test.sh
bash scripts/deploy-local-images.test.sh
