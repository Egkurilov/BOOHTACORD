#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../../tools/build/legacy_server/build_images.sh" "$@"
