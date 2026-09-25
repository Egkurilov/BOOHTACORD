#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workflow="$root/.gitverse/workflows/rehearse-compatible-rollback.yaml"
[[ -r "$workflow" ]]
grep -Fq 'workflow_dispatch:' "$workflow"
grep -Fq 'current_sha:' "$workflow"
grep -Fq 'previous_sha:' "$workflow"
grep -Fq 'observers_confirmed:' "$workflow"
grep -Fq 'group: v-bootybay-production' "$workflow"
grep -Fq 'cancel-in-progress: false' "$workflow"
grep -Fq "github.ref_name == 'master'" "$workflow"
grep -Fq 'bash scripts/configure-deploy-ssh.sh' "$workflow"
grep -Fq 'git rev-parse HEAD' "$workflow"
grep -Fq 'scripts/qa12_rollback/rehearse.sh' "$workflow"
grep -Fq 'StrictHostKeyChecking=yes' "$workflow"
if grep -Eq '^  push:|^  pull_request:' "$workflow"; then exit 1; fi
echo 'QA-12 manual workflow source contract passed'
