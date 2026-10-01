#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../tools/release/rollout/deploy-images-volume-guard.test.sh" "$@"
