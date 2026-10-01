#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../../tools/qa/legacy_rollback/image_ref.test.sh" "$@"
