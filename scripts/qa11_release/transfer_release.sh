#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../../tools/release/legacy_transfer/transfer_release.sh" "$@"
