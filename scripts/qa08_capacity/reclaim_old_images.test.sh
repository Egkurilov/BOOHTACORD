#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../../tools/ops/docker_storage/reclaim_old_images.test.sh" "$@"
