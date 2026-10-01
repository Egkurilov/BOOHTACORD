#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../tools/verify/android_client/verify-android-client.sh" "$@"
