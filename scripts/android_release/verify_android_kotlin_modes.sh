#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/../../tools/verify/android_kotlin/verify_android_kotlin_modes.sh" "$@"
