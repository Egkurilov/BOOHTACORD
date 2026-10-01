#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
desktop_dir="$repo_dir/desktop"
build_log="$(mktemp)"
trap 'rm -f "$build_log"' EXIT

check_build() {
  local label="$1"
  shift
  echo "$label"
  if ! "$@" >"$build_log" 2>&1; then
    cat "$build_log"
    return 1
  fi
  cat "$build_log"
  if grep -Fq 'WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP)' "$build_log"; then
    echo 'Unexpected Flutter KGP compatibility warning.' >&2
    return 1
  fi
}

cd "$desktop_dir"
check_build "Checking legacy-KGP compatibility mode from android/gradle.properties" \
  flutter build apk --debug --no-pub

cd "$desktop_dir/android"
check_build "Checking AGP built-in Kotlin mode without a connected device" \
  ./gradlew :app:assembleDebug -Pandroid.builtInKotlin=true --no-daemon
