#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

grep -Fq "Android client is an approved native client" \
  "$repo_root/docs/adr/ADR-006-android-client.md"
grep -Fq "title: Android native client and APK" \
  "$repo_root/backlog/tasks.yaml"
grep -Fq -- "- android/" "$repo_root/desktop/README.md"
test -f "$repo_root/desktop/android/app/src/main/AndroidManifest.xml"
test -f "$repo_root/desktop/android/app/build.gradle.kts"
grep -Fq 'android.permission.INTERNET' \
  "$repo_root/desktop/android/app/src/main/AndroidManifest.xml"
grep -Fq 'android.permission.RECORD_AUDIO' \
  "$repo_root/desktop/android/app/src/main/AndroidManifest.xml"
grep -Fq 'applicationId = "ru.boohtacord.app"' \
  "$repo_root/desktop/android/app/build.gradle.kts"

echo "Android client contract OK."
