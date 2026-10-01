#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
desktop_dir="$repo_dir/desktop"

cd "$desktop_dir"
echo "Checking legacy-KGP compatibility mode from android/gradle.properties"
flutter build apk --debug --no-pub

cd "$desktop_dir/android"
echo "Checking AGP built-in Kotlin mode without a connected device"
./gradlew :app:assembleDebug -Pandroid.builtInKotlin=true --no-daemon
