#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../../tools/ops/docker_storage/prune_build_cache.sh" "$@"
