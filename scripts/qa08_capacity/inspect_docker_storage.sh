#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../../tools/ops/docker_storage/inspect_docker_storage.sh" "$@"
