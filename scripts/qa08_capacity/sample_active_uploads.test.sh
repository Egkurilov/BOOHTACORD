#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../../tools/qa/active_uploads/sample_active_uploads.test.sh" "$@"
