#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
temporary_root="$(mktemp -d)"
temporary_parent="$(cd "$(dirname "$temporary_root")" && pwd -P)"
temporary_root="$(cd "$temporary_root" && pwd -P)"
cleanup() {
  [[ "$temporary_root" == "$temporary_parent"/tmp.* && -d "$temporary_root" ]] || return 1
  rm -rf -- "$temporary_root"
}
trap cleanup EXIT
release_root="$temporary_root/releases"
state_dir="$temporary_root/state"
bin_dir="$temporary_root/bin"
current="$(printf 'a%.0s' {1..40})"
previous="$(printf 'b%.0s' {1..40})"
current_digest="sha256:$(printf '1%.0s' {1..64})"
previous_digest="sha256:$(printf '3%.0s' {1..64})"
mkdir -p "$release_root/$current/scripts/qa12_rollback" "$release_root/$previous" "$state_dir" "$bin_dir"
for service in api web; do
  printf '{"index_digest":"%s"}\n' "$current_digest" > "$release_root/$current/$service.oci.json"
  printf '{"index_digest":"%s"}\n' "$previous_digest" > "$release_root/$previous/$service.oci.json"
  printf 'voice-platform-%s@%s\n' "$service" "$current_digest" > "$state_dir/running-$service"
done
cat > "$release_root/$current/scripts/qa12_rollback/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'preflight %s %s\n' "$1" "$2" >> "$QA12_LOG"
EOF
cat > "$release_root/$current/scripts/deploy-images.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'deploy %s %s\n' "$API_IMAGE" "$WEB_IMAGE" >> "$QA12_LOG"
printf '%s\n' "$API_IMAGE" > "$QA12_STATE/running-api"
printf '%s\n' "$WEB_IMAGE" > "$QA12_STATE/running-web"
EOF
cat > "$release_root/$current/scripts/audit-attachment-volume.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'audit %s\n' "$1" >> "$QA12_LOG"
expected="voice-platform-api@$QA12_CURRENT_DIGEST"
[[ "$1" != "$QA12_PREVIOUS" ]] || expected="voice-platform-api@$QA12_PREVIOUS_DIGEST"
[[ "$(cat "$QA12_STATE/running-api")" == "$expected" ]]
if [[ "${QA12_FAIL_PREVIOUS_AUDIT:-0}" == 1 && "$1" == "$QA12_PREVIOUS" ]]; then exit 29; fi
EOF
cat > "$bin_dir/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  'image inspect') printf 'sha256:%s\n' "$(printf '1%.0s' {1..64})" ;;
  'volume inspect')
    if [[ "${QA12_VOLUME_DRIFT:-0}" == 1 && "$(cat "$QA12_STATE/running-api")" == "voice-platform-api@$QA12_PREVIOUS_DIGEST" ]]; then
      printf '%s|local|/unexpected/%s\n' "$5" "$5"
    else
      printf '%s|local|/volumes/%s\n' "$5" "$5"
    fi ;;
  'ps --filter')
    if [[ "$*" == *'service=api'* ]]; then printf 'aaaaaaaaaaaa\n'; else printf 'bbbbbbbbbbbb\n'; fi ;;
  'inspect --format')
    if [[ "$3" == '{{.Image}}' ]]; then
      printf 'sha256:%s\n' "$(printf '1%.0s' {1..64})"
    elif [[ "$4" == aaaaaaaaaaaa ]]; then cat "$QA12_STATE/running-api"; else cat "$QA12_STATE/running-web"; fi ;;
  *) exit 1 ;;
esac
EOF
cat > "$bin_dir/sleep" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sleep %s\n' "$*" >> "$QA12_LOG"
if [[ "${QA12_INTERRUPT_ON_SLEEP:-0}" == 1 ]]; then kill -TERM "$PPID"; fi
EOF
chmod 0755 "$bin_dir/docker" "$bin_dir/sleep"
if ! python3 -c 'import sys' >/dev/null 2>&1; then
  printf '#!/usr/bin/env bash\nexec python "$@"\n' > "$bin_dir/python3"
  chmod 0755 "$bin_dir/python3"
fi
export PATH="$bin_dir:$PATH" QA12_STATE="$state_dir" QA12_PREVIOUS="$previous" QA12_OBSERVE_SECONDS=30
export QA12_CURRENT="$current" QA12_RELEASE_ROOT="$release_root"
export QA12_CURRENT_DIGEST="$current_digest" QA12_PREVIOUS_DIGEST="$previous_digest"
export QA12_LOG="$temporary_root/commands.log"
script="$root/scripts/qa12_rollback/rehearse.sh"
bash "$script" "$current" "$previous" "$release_root" > "$temporary_root/success.out"
[[ "$(cat "$state_dir/running-api")" == "voice-platform-api@$current_digest" ]]
[[ "$(cat "$state_dir/running-web")" == "voice-platform-web@$current_digest" ]]
[[ "$(grep -c '^deploy ' "$QA12_LOG")" == 2 ]]
[[ "$(grep -c '^audit ' "$QA12_LOG")" == 3 ]]
grep -Fq 'sleep 30' "$QA12_LOG"
grep -Fq 'rehearsal=source-checks-pass' "$temporary_root/success.out"
printf 'voice-platform-api@%s\n' "$current_digest" > "$state_dir/running-api"
printf 'voice-platform-web@%s\n' "$current_digest" > "$state_dir/running-web"
: > "$QA12_LOG"
QA12_FAIL_PREVIOUS_AUDIT=1 bash "$script" "$current" "$previous" "$release_root" > "$temporary_root/failure.out" 2>&1 && exit 1
[[ "$(cat "$state_dir/running-api")" == "voice-platform-api@$current_digest" ]]
[[ "$(cat "$state_dir/running-web")" == "voice-platform-web@$current_digest" ]]
[[ "$(grep -c '^deploy ' "$QA12_LOG")" == 2 ]]
grep -Fq 'attempting current image restore' "$temporary_root/failure.out"
printf 'voice-platform-api@%s\n' "$current_digest" > "$state_dir/running-api"
printf 'voice-platform-web@%s\n' "$current_digest" > "$state_dir/running-web"
: > "$QA12_LOG"
QA12_INTERRUPT_ON_SLEEP=1 bash "$script" "$current" "$previous" "$release_root" > "$temporary_root/interrupted.out" 2>&1 && exit 1
[[ "$(cat "$state_dir/running-api")" == "voice-platform-api@$current_digest" ]]
grep -Fq 'terminated; current restore will be attempted' "$temporary_root/interrupted.out"
grep -Fq 'attempting current image restore' "$temporary_root/interrupted.out"
printf 'voice-platform-api@%s\n' "$current_digest" > "$state_dir/running-api"
printf 'voice-platform-web@%s\n' "$current_digest" > "$state_dir/running-web"
: > "$QA12_LOG"
QA12_VOLUME_DRIFT=1 bash "$script" "$current" "$previous" "$release_root" > "$temporary_root/drift.out" 2>&1 && exit 1
[[ "$(cat "$state_dir/running-api")" == "voice-platform-api@$previous_digest" ]]
[[ "$(grep -c '^deploy ' "$QA12_LOG")" == 1 ]]
grep -Fq 'named volume identity changed' "$temporary_root/drift.out"
grep -Fq 'current restore requires operator diagnosis' "$temporary_root/drift.out"
for service in api web; do printf 'voice-platform-%s@%s\n' "$service" "$current_digest" > "$state_dir/running-$service"; done
: > "$QA12_LOG"
bash "$script" "$current" "$previous" "$release_root" > "$temporary_root/digest.out"
[[ "$(cat "$state_dir/running-api")" == "voice-platform-api@$current_digest" ]]
grep -Fq "deploy voice-platform-api@$previous_digest voice-platform-web@$previous_digest" "$QA12_LOG"
grep -Fq "deploy voice-platform-api@$current_digest voice-platform-web@$current_digest" "$QA12_LOG"
if grep -Eq '(^| )down( |$)|(^| )volume (rm|prune)( |$)' "$QA12_LOG"; then exit 1; fi
echo 'QA-12 two-way rehearsal tests passed'
