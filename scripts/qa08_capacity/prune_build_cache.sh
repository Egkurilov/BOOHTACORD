#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'QA-08 build-cache recovery stopped: %s\n' "$1" >&2; exit 1; }
live=4df09bd772acac695290448ba77735f7755a7fa0
built=9201f219f9c1311a3b58f3bacf040cda00b4029c
release_root="${VOICE_PLATFORM_RELEASE_ROOT:-/opt/voice-platform-releases}"
guard="$release_root/$built/scripts/check-attachment-volume-headroom.sh"
[[ -f "$guard" ]] || fail 'the trusted release guard is unavailable'

docker_root="$(docker info --format '{{.DockerRootDir}}')" || fail 'Docker root is unavailable'
mountpoint="$(docker volume inspect --format '{{.Mountpoint}}' voice-platform_attachments-data)" || fail 'attachment volume is unavailable'
[[ "$docker_root" == /* && -d "$docker_root" && "$mountpoint" == /* && -d "$mountpoint" ]] || fail 'storage paths are invalid'
docker_fs="$(findmnt -T "$docker_root" -n -o SOURCE)" || fail 'Docker filesystem is unknown'
volume_fs="$(findmnt -T "$mountpoint" -n -o SOURCE)" || fail 'attachment filesystem is unknown'
[[ -n "$docker_fs" && "$docker_fs" == "$volume_fs" ]] || fail 'Docker cache and attachments use different filesystems'

for service in api web; do
  running="$(docker ps --filter label=com.docker.compose.project=voice-platform --filter "label=com.docker.compose.service=$service" --format '{{.Image}}')" || fail 'running image lookup failed'
  [[ "$running" == "voice-platform-$service:$live" ]] || fail "unexpected running $service image"
done

sample() {
  reading="$(df -B1 --output=avail,size -- "$mountpoint")" || fail 'volume measurement failed'
  numbers="$(printf '%s\n' "$reading" | awk 'NR == 2 { print $1, $2 } END { if (NR != 2) exit 1 }')" || fail 'volume measurement is invalid'
  read -r available total <<< "$numbers"
  [[ "$available" =~ ^[0-9]+$ && "$total" =~ ^[0-9]+$ ]] || fail 'volume numbers are invalid'
  available=$((10#$available)); total=$((10#$total))
  (( total > 0 && available <= total )) || fail 'volume numbers are inconsistent'
  protected=$(((total + 9) / 10))
  (( protected >= 2147483648 )) || protected=2147483648
  required=$((protected * 2 + 25000000))
  target=$((required + 1250000000))
}

sample
printf 'QA-08 before cache prune: %s available; %s required; %s build target\n' "$available" "$required" "$target"
if (( available < target )); then
  # Docker removes only unused build cache; no image, container or volume prune.
  docker builder prune --all --force
  sample
fi
printf 'QA-08 after cache step: %s available; %s required; %s build target\n' "$available" "$required" "$target"
(( available >= target )) || fail "insufficient exact-volume headroom after cache prune ($available < $target bytes)"
bash "$guard" || fail 'the release guard rejected restored headroom'
