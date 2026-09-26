#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'QA-12 rollback preflight failed: %s\n' "$1" >&2; exit 1; }
[[ $# -ge 2 && $# -le 3 ]] || fail 'current and previous SHA are required'
current="$1"
previous="$2"
[[ "$current" =~ ^[0-9a-f]{40}$ && "$previous" =~ ^[0-9a-f]{40}$ && "$current" != "$previous" ]] || fail 'invalid or equal revisions'
release_root="$(cd "${3:-/opt/voice-platform-releases}" && pwd -P)" || fail 'release root unavailable'
current_dir="$release_root/$current"
previous_dir="$release_root/$previous"
source "$(dirname "${BASH_SOURCE[0]}")/image_ref.sh"
for release_dir in "$current_dir" "$previous_dir"; do
  [[ -d "$release_dir" && "$(cd "$release_dir" && pwd -P)" == "$release_dir" ]] || fail 'exact release directory unavailable'
  [[ -d "$release_dir/backend" && -r "$release_dir/compose.yaml" && -r "$release_dir/docker/Caddyfile" ]] || fail 'release source incomplete'
done
[[ -r "$current_dir/.env" && -r "$current_dir/scripts/deploy-images.sh" && -r "$current_dir/scripts/audit-attachment-volume.sh" ]] || fail 'current release scripts or environment unavailable'

# This rehearsal accepts only an unchanged backend, migration set and Compose topology.
diff -qr "$current_dir/backend" "$previous_dir/backend" >/dev/null || fail 'backend or migration tree differs'
cmp -s "$current_dir/compose.yaml" "$previous_dir/compose.yaml" || fail 'Compose topology differs'
cmp -s "$current_dir/docker/Caddyfile" "$previous_dir/docker/Caddyfile" || fail 'proxy configuration differs'

for service in api web; do
  upper="${service^^}"
  expected="$(qa12_image_ref "$release_root" "$current" "$service")" || fail "current $service image receipt invalid"
  configured="$(sed -n "s/^${upper}_IMAGE=//p" "$current_dir/.env")"
  [[ "$configured" == "$expected" ]] || fail "current $service image in environment differs"
  container="$(docker ps --filter label=com.docker.compose.project=voice-platform --filter "label=com.docker.compose.service=$service" --format '{{.ID}}')" || fail "running $service unavailable"
  [[ "$container" =~ ^[0-9a-f]{12,64}$ ]] || fail "expected exactly one running $service container"
  running="$(docker inspect --format '{{.Config.Image}}' "$container")" || fail "running $service image unavailable"
  [[ "$running" == "$expected" ]] || fail "running $service image differs"
  current_image_id=''
  for sha in "$current" "$previous"; do
    tag="$(qa12_image_ref "$release_root" "$sha" "$service")" || fail "local $service image receipt invalid"
    image_id="$(docker image inspect --format '{{.Id}}' "$tag")" || fail "local $service image tag unavailable"
    [[ "$image_id" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "local $service image ID invalid"
    if [[ "$sha" == "$current" ]]; then current_image_id="$image_id"; fi
    printf 'image=%s|%s\n' "$tag" "$image_id"
  done
  running_id="$(docker inspect --format '{{.Image}}' "$container")" || fail "running $service image ID unavailable"
  [[ "$running_id" == "$current_image_id" ]] || fail "running $service image ID differs from current tag"
done

for name in postgres-data attachments-data caddy-data caddy-config; do
  expected="voice-platform_$name"
  identity="$(docker volume inspect --format '{{.Name}}|{{.Driver}}|{{.Mountpoint}}' "$expected")" || fail "volume $expected unavailable"
  IFS='|' read -r actual driver mountpoint extra <<< "$identity"
  [[ "$actual" == "$expected" && "$driver" == local && "$mountpoint" == /* && -z "${extra:-}" && -d "$mountpoint" ]] || fail "volume $expected identity invalid"
  printf 'volume=%s\n' "$identity"
done
printf 'current_sha=%s\nprevious_sha=%s\npreflight=pass\n' "$current" "$previous"
