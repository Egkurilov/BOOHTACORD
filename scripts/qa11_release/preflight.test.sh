#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../../tools/release/preflight/preflight.test.sh" "$@"
