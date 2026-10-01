#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../tools/ops/attachment_headroom/check-attachment-volume-headroom.sh" "$@"
