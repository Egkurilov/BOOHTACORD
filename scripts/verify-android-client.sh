#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

grep -Fq "Android client is an approved native client" \
  "$repo_root/docs/adr/ADR-006-android-client.md"
grep -Fq "title: Android native client and APK" \
  "$repo_root/backlog/tasks.yaml"
test -f "$repo_root/clients/flutter/pubspec.yaml"
test -f "$repo_root/clients/flutter/android/app/src/main/AndroidManifest.xml"
test -f "$repo_root/clients/flutter/android/app/build.gradle.kts"
grep -Fq 'android.permission.INTERNET' \
  "$repo_root/clients/flutter/android/app/src/main/AndroidManifest.xml"
grep -Fq 'android.permission.RECORD_AUDIO' \
  "$repo_root/clients/flutter/android/app/src/main/AndroidManifest.xml"
grep -Fq 'applicationId = "ru.boohtacord.app"' \
  "$repo_root/clients/flutter/android/app/build.gradle.kts"

echo "Android client contract OK."
