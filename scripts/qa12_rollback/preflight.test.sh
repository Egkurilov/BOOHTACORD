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
bin_dir="$temporary_root/bin"
state_dir="$temporary_root/state"
mkdir -p "$release_root" "$bin_dir" "$state_dir/volumes"
current="$(printf 'a%.0s' {1..40})"
previous="$(printf 'b%.0s' {1..40})"
for sha in "$current" "$previous"; do
  mkdir -p "$release_root/$sha/backend" "$release_root/$sha/docker" "$release_root/$sha/scripts"
  printf 'same backend\n' > "$release_root/$sha/backend/main.go"
  printf 'services: {}\n' > "$release_root/$sha/compose.yaml"
  printf 'same proxy\n' > "$release_root/$sha/docker/Caddyfile"
done
printf '#!/usr/bin/env bash\n' > "$release_root/$current/scripts/deploy-images.sh"
printf '#!/usr/bin/env bash\n' > "$release_root/$current/scripts/audit-attachment-volume.sh"
printf 'API_IMAGE=voice-platform-api:%s\nWEB_IMAGE=voice-platform-web:%s\n' "$current" "$current" > "$release_root/$current/.env"
for name in postgres-data attachments-data caddy-data caddy-config; do
  mkdir -p "$state_dir/volumes/voice-platform_$name"
done
printf 'voice-platform-api:%s\n' "$current" > "$state_dir/running-api"
printf 'voice-platform-web:%s\n' "$current" > "$state_dir/running-web"
cat > "$bin_dir/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  'image inspect')
    [[ "${QA12_MISSING_PREVIOUS:-0}" != 1 || "$5" != "voice-platform-api:$QA12_PREVIOUS" ]] || exit 1
    [[ "$5" =~ ^voice-platform-(api|web):[ab]{40}$ || "$5" =~ ^voice-platform-(api|web)@sha256:1{64}$ ]] || exit 1
    if [[ "${QA12_RETAG_CURRENT:-0}" == 1 && "$5" == "voice-platform-api:$QA12_CURRENT" ]]; then
      printf 'sha256:%s\n' "$(printf '2%.0s' {1..64})"
    else
      printf 'sha256:%s\n' "$(printf '1%.0s' {1..64})"
    fi
    ;;
  'volume inspect')
    [[ "$5" == voice-platform_* ]]
    [[ -d "$QA12_STATE/volumes/$5" ]] || exit 1
    printf '%s|local|%s/volumes/%s\n' "$5" "$QA12_STATE" "$5"
    ;;
  'ps --filter')
    if [[ "$*" == *'service=api'* ]]; then printf 'aaaaaaaaaaaa\n'; else printf 'bbbbbbbbbbbb\n'; fi
    ;;
  'inspect --format')
    if [[ "$3" == '{{.Image}}' ]]; then
      printf 'sha256:%s\n' "$(printf '1%.0s' {1..64})"
    elif [[ "$4" == aaaaaaaaaaaa ]]; then cat "$QA12_STATE/running-api"; else cat "$QA12_STATE/running-web"; fi
    ;;
  *) exit 1 ;;
esac
EOF
chmod 0755 "$bin_dir/docker"
if ! python3 -c 'import sys' >/dev/null 2>&1; then
  printf '#!/usr/bin/env bash\nexec python "$@"\n' > "$bin_dir/python3"
  chmod 0755 "$bin_dir/python3"
fi
export PATH="$bin_dir:$PATH" QA12_STATE="$state_dir" QA12_CURRENT="$current" QA12_PREVIOUS="$previous"
script="$root/scripts/qa12_rollback/preflight.sh"
bash "$script" "$current" "$previous" "$release_root" > "$temporary_root/passed.log"
grep -Fq "current_sha=$current" "$temporary_root/passed.log"
grep -Fq "previous_sha=$previous" "$temporary_root/passed.log"
grep -Fq "volume=voice-platform_attachments-data|local|" "$temporary_root/passed.log"
QA12_MISSING_PREVIOUS=1 bash "$script" "$current" "$previous" "$release_root" > "$temporary_root/missing.log" 2>&1 && exit 1
QA12_RETAG_CURRENT=1 bash "$script" "$current" "$previous" "$release_root" > "$temporary_root/retag.log" 2>&1 && exit 1
printf 'voice-platform-api:%s\n' "$previous" > "$state_dir/running-api"
bash "$script" "$current" "$previous" "$release_root" > "$temporary_root/drift.log" 2>&1 && exit 1
printf 'voice-platform-api:%s\n' "$current" > "$state_dir/running-api"
printf 'different backend\n' > "$release_root/$previous/backend/main.go"
bash "$script" "$current" "$previous" "$release_root" > "$temporary_root/backend.log" 2>&1 && exit 1
printf 'same backend\n' > "$release_root/$previous/backend/main.go"
printf 'different compose\n' > "$release_root/$previous/compose.yaml"
bash "$script" "$current" "$previous" "$release_root" > "$temporary_root/compose.log" 2>&1 && exit 1
printf 'services: {}\n' > "$release_root/$previous/compose.yaml"
digest="sha256:$(printf '1%.0s' {1..64})"
for service in api web; do
  printf '{"index_digest":"%s"}\n' "$digest" > "$release_root/$current/$service.oci.json"
  printf 'voice-platform-%s@%s\n' "$service" "$digest" > "$state_dir/running-$service"
done
printf 'API_IMAGE=voice-platform-api@%s\nWEB_IMAGE=voice-platform-web@%s\n' "$digest" "$digest" > "$release_root/$current/.env"
bash "$script" "$current" "$previous" "$release_root" > "$temporary_root/digest.log"
grep -Fq "image=voice-platform-api@$digest|$digest" "$temporary_root/digest.log"
rmdir "$state_dir/volumes/voice-platform_postgres-data"
bash "$script" "$current" "$previous" "$release_root" > "$temporary_root/volume.log" 2>&1 && exit 1
echo 'QA-12 read-only preflight tests passed'
