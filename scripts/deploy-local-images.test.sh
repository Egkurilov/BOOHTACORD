#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../tools/release/legacy_install/deploy-local-images.test.sh" "$@"
