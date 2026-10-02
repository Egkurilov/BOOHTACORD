#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'Deploy headroom recovery stopped: %s\n' "$1" >&2; exit 1; }

docker_root="$(docker info --format '{{.DockerRootDir}}')" || fail 'Docker root unavailable'
mountpoint="$(docker volume inspect --format '{{.Mountpoint}}' voice-platform_attachments-data)" || fail 'attachment volume unavailable'
[[ "$docker_root" == /* && -d "$docker_root" && "$mountpoint" == /* && -d "$mountpoint" ]] || fail 'storage paths invalid'
docker_fs="$(findmnt -T "$docker_root" -n -o SOURCE)" || fail 'Docker filesystem unknown'
volume_fs="$(findmnt -T "$mountpoint" -n -o SOURCE)" || fail 'attachment filesystem unknown'
[[ -n "$docker_fs" && "$docker_fs" == "$volume_fs" ]] || fail 'Docker and attachments use different filesystems'

# Require both production services and protect the images of every container.
for service in api web; do
  running="$(docker ps -q --filter label=com.docker.compose.project=voice-platform --filter "label=com.docker.compose.service=$service")" || fail "running $service lookup failed"
  [[ "$running" =~ ^[A-Za-z0-9]+$ ]] || fail "exactly one running $service container is required"
done
containers="$(docker ps -aq)" || fail 'container inventory failed'
[[ -n "$containers" ]] || fail 'container inventory empty'
declare -A protected_ids=()
while IFS= read -r container; do
  [[ -n "$container" ]] || continue
  id="$(docker inspect --format '{{.Image}}' "$container")" || fail 'container image lookup failed'
  [[ "$id" =~ ^sha256:[0-9a-f]{64}$ ]] || fail 'invalid container image ID'
  protected_ids["$id"]=1
done <<< "$containers"

sample() {
  local reading numbers total protected
  reading="$(df -B1 --output=avail,size -- "$mountpoint")" || fail 'volume measurement failed'
  numbers="$(printf '%s\n' "$reading" | awk 'NR == 2 { print $1, $2 } END { if (NR != 2) exit 1 }')" || fail 'invalid volume measurement'
  read -r available total <<< "$numbers"
  [[ "$available" =~ ^[0-9]+$ && "$total" =~ ^[0-9]+$ ]] || fail 'invalid volume numbers'
  available=$((10#$available)); total=$((10#$total))
  (( total > 0 && available <= total )) || fail 'inconsistent volume numbers'
  protected=$(((total + 9) / 10))
  (( protected >= 2147483648 )) || protected=2147483648
  required=$((protected * 2 + 25000000))
  target=$((required + 1250000000))
}

sample
printf 'Deploy headroom: %s bytes available; %s required; %s build target.\n' "$available" "$required" "$target"
if (( available >= target )); then exit 0; fi

# Docker removes only unused build cache. Never prune volumes or containers.
docker builder prune --all --force
sample
if (( available >= target )); then
  printf 'Deploy headroom restored: %s bytes available.\n' "$available"
  exit 0
fi

# Remove only complete, revision-labelled release image pairs. Retain the ten
# newest pairs and every image referenced by any container for rollback.
refs="$(docker image ls --format '{{.Repository}}:{{.Tag}}')" || fail 'image inventory failed'
rows=()
while IFS= read -r api; do
  [[ "$api" =~ ^voice-platform-api:([0-9a-f]{40})$ ]] || continue
  revision="${BASH_REMATCH[1]}"
  web="voice-platform-web:$revision"
  docker image inspect "$web" >/dev/null 2>&1 || continue
  api_label="$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$api")" || fail 'API image label unavailable'
  web_label="$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$web")" || fail 'web image label unavailable'
  [[ "$api_label" == "$revision" && "$web_label" == "$revision" ]] || continue
  created="$(docker image inspect --format '{{.Created}}' "$api")" || fail 'image creation time unavailable'
  [[ "$created" == ????-??-??T* ]] || fail 'invalid image creation time'
  rows+=("$created $revision")
done <<< "$refs"
(( ${#rows[@]} > 10 )) || fail "fewer than eleven eligible release pairs ($available < $target bytes)"
mapfile -t ordered < <(printf '%s\n' "${rows[@]}" | LC_ALL=C sort -r)

for ((index=${#ordered[@]}-1; index>=10; index--)); do
  revision="${ordered[index]##* }"
  api="voice-platform-api:$revision"
  web="voice-platform-web:$revision"
  api_id="$(docker image inspect --format '{{.Id}}' "$api")" || fail 'API image changed during cleanup'
  web_id="$(docker image inspect --format '{{.Id}}' "$web")" || fail 'web image changed during cleanup'
  [[ "$api_id" =~ ^sha256:[0-9a-f]{64}$ && "$web_id" =~ ^sha256:[0-9a-f]{64}$ ]] || fail 'invalid release image ID'
  [[ -z "${protected_ids[$api_id]:-}" && -z "${protected_ids[$web_id]:-}" ]] || continue
  docker image rm --no-prune "$api" >/dev/null || fail 'API image removal failed'
  docker image rm --no-prune "$web" >/dev/null || fail 'web image removal failed'
  printf 'Removed unused release image pair %s.\n' "$revision"
  sample
  if (( available >= target )); then
    printf 'Deploy headroom restored: %s bytes available.\n' "$available"
    exit 0
  fi
done
fail "eligible image cleanup did not restore build headroom ($available < $target bytes)"
