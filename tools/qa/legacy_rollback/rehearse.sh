#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'QA-12 rehearsal failed: %s\n' "$1" >&2; exit 1; }
[[ $# -ge 2 && $# -le 3 ]] || fail 'current and previous SHA are required'
current="$1"
previous="$2"
[[ "$current" =~ ^[0-9a-f]{40}$ && "$previous" =~ ^[0-9a-f]{40}$ && "$current" != "$previous" ]] || fail 'invalid or equal revisions'
observe_seconds="${QA12_OBSERVE_SECONDS:-60}"
[[ "$observe_seconds" =~ ^[0-9]+$ ]] || fail 'observer window invalid'
(( observe_seconds >= 30 && observe_seconds <= 300 )) || fail 'observer window outside 30..300 seconds'
release_root="$(cd "${3:-/opt/voice-platform-releases}" && pwd -P)" || fail 'release root unavailable'
current_dir="$release_root/$current"
source "$(dirname "${BASH_SOURCE[0]}")/image_ref.sh"
bash "$current_dir/tools/qa/legacy_rollback/preflight.sh" "$current" "$previous" "$release_root"

volume_snapshot() {
  local name
  for name in postgres-data attachments-data caddy-data caddy-config; do
    docker volume inspect --format '{{.Name}}|{{.Driver}}|{{.Mountpoint}}' "voice-platform_$name"
  done
}

assert_running() {
  local revision="$1" service container running running_id tag_id
  for service in api web; do
    container="$(docker ps --filter label=com.docker.compose.project=voice-platform --filter "label=com.docker.compose.service=$service" --format '{{.ID}}')"
    [[ "$container" =~ ^[0-9a-f]{12,64}$ ]] || fail "expected one running $service container"
    running="$(docker inspect --format '{{.Config.Image}}' "$container")"
    expected="$(qa12_image_ref "$release_root" "$revision" "$service")" || fail "image receipt invalid"
    [[ "$running" == "$expected" ]] || fail "running $service image differs"
    running_id="$(docker inspect --format '{{.Image}}' "$container")"
    tag_id="$(docker image inspect --format '{{.Id}}' "$expected")"
    [[ "$running_id" =~ ^sha256:[0-9a-f]{64}$ && "$running_id" == "$tag_id" ]] || fail "running $service image ID differs from tag"
  done
}

deploy_revision() {
  local revision="$1"
  local api_ref web_ref
  api_ref="$(qa12_image_ref "$release_root" "$revision" api)" || fail 'API image receipt invalid'
  web_ref="$(qa12_image_ref "$release_root" "$revision" web)" || fail 'web image receipt invalid'
  env VOICE_PLATFORM_DIR="$current_dir" \
    API_IMAGE="$api_ref" WEB_IMAGE="$web_ref" \
    bash "$current_dir/tools/release/rollout/deploy-images.sh"
}

audit_revision() { bash "$current_dir/tools/ops/attachment_audit/audit-attachment-volume.sh" "$1"; }
baseline="$(volume_snapshot)" || fail 'volume identity unavailable'
assert_volumes() {
  local observed
  observed="$(volume_snapshot)" || fail 'volume identity unavailable'
  if [[ "$observed" != "$baseline" ]]; then
    restore_allowed=0
    fail 'named volume identity changed; stop for operator diagnosis'
  fi
}

restore_needed=0
restore_attempted=0
restore_allowed=1
cleanup() {
  local status=$? observed=''
  trap - EXIT
  if [[ "$restore_needed" -eq 1 && "$restore_attempted" -eq 0 && "$restore_allowed" -eq 1 ]]; then
    if ! observed="$(volume_snapshot)" || [[ "$observed" != "$baseline" ]]; then
      printf 'QA-12: volume identity changed or unavailable; skip automatic restore and require operator diagnosis\n' >&2
      exit 1
    fi
    restore_attempted=1
    printf 'QA-12: attempting current image restore after failure\n' >&2
    if ! deploy_revision "$current" || ! assert_running "$current" || ! audit_revision "$current" || ! assert_volumes; then
      printf 'QA-12: current restore failed; operator diagnosis required\n' >&2
      exit 1
    fi
  elif [[ "$restore_needed" -eq 1 ]]; then
    printf 'QA-12: current restore requires operator diagnosis\n' >&2
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'printf "QA-12: interrupted; current restore will be attempted if volume identity is unchanged\n" >&2; exit 130' INT
trap 'printf "QA-12: terminated; current restore will be attempted if volume identity is unchanged\n" >&2; exit 143' TERM

assert_running "$current"
audit_revision "$current"
assert_volumes
restore_needed=1
deploy_revision "$previous"
assert_running "$previous"
audit_revision "$previous"
assert_volumes
printf 'QA-12: previous image healthy; browser observation window %s seconds\n' "$observe_seconds"
sleep "$observe_seconds"
assert_volumes
restore_attempted=1
deploy_revision "$current"
assert_running "$current"
restore_needed=0
audit_revision "$current"
assert_volumes
printf 'rehearsal=source-checks-pass\ncurrent_sha=%s\nprevious_sha=%s\n' "$current" "$previous"
