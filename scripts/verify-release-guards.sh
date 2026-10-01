#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../tools/ci/release_guards/verify-release-guards.sh" "$@"
