#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../tools/ci/postgres/start-ci-postgres.sh" "$@"
