#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../../tools/ops/docker_storage/prepare_host_storage.sh" "$@"
