#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../../tools/verify/running_images/verify_running.sh" "$@"
