#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'QA-08 image reclaim stopped: %s\n' "$1" >&2; exit 1; }
live=4df09bd772acac695290448ba77735f7755a7fa0
rollback=4ce70a7bf498dca5f8e8ae7ea2d5bf68551e6431
built=9201f219f9c1311a3b58f3bacf040cda00b4029c
release_root="${VOICE_PLATFORM_RELEASE_ROOT:-/opt/voice-platform-releases}"
guard="$release_root/$built/tools/ops/attachment_headroom/check-attachment-volume-headroom.sh"
[[ -f "$guard" ]] || guard="$release_root/$built/scripts/check-attachment-volume-headroom.sh"
[[ -f "$guard" ]] || fail 'the trusted release guard is unavailable'

docker_root="$(docker info --format '{{.DockerRootDir}}')" || fail 'Docker root is unavailable'
mountpoint="$(docker volume inspect --format '{{.Mountpoint}}' voice-platform_attachments-data)" || fail 'attachment volume is unavailable'
[[ "$docker_root" == /* && -d "$docker_root" && "$mountpoint" == /* && -d "$mountpoint" ]] || fail 'storage paths are invalid'
docker_fs="$(findmnt -T "$docker_root" -n -o SOURCE)" || fail 'Docker filesystem is unknown'
volume_fs="$(findmnt -T "$mountpoint" -n -o SOURCE)" || fail 'attachment filesystem is unknown'
[[ -n "$docker_fs" && "$docker_fs" == "$volume_fs" ]] || fail 'Docker images and attachments use different filesystems'

for service in api web; do
  running="$(docker ps --filter label=com.docker.compose.project=voice-platform --filter "label=com.docker.compose.service=$service" --format '{{.Image}}')" || fail 'running image lookup failed'
  [[ "$running" == "voice-platform-$service:$live" ]] || fail "unexpected running $service image"
done

protected_ids=()
for sha in "$live" "$rollback" "$built" ba38bb3e6f7d18d20bbe5d93b1fa8b85ebd580e6 352f8a8ce2beade4f8beb534e855108c7f53bd8f; do
  for service in api web; do
    id="$(docker image inspect --format '{{.Id}}' "voice-platform-$service:$sha")" || fail 'a protected image is missing'
    [[ "$id" =~ ^sha256:[0-9a-f]{64}$ ]] || fail 'a protected image ID is invalid'
    protected_ids+=("$id")
  done
done
containers="$(docker ps -aq)" || fail 'container inventory failed'
while IFS= read -r container; do
  [[ -n "$container" ]] || continue
  id="$(docker inspect --format '{{.Image}}' "$container")" || fail 'container image lookup failed'
  [[ "$id" =~ ^sha256:[0-9a-f]{64}$ ]] || fail 'container image ID is invalid'
  protected_ids+=("$id")
done <<< "$containers"

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

finish_if_ready() {
  sample
  if (( available >= target )); then
    bash "$guard" || fail 'the release guard rejected restored headroom'
    printf 'QA-08 headroom ready: %s available, %s required, %s build target\n' "$available" "$required" "$target"
    exit 0
  fi
}
finish_if_ready

# Exact old commit tags observed in trusted run #1649232, oldest first.
old_shas=(
  a904b2afd92bd153caa60a768383701b4088ca46 cb10a3b353fd72a0a6eb8c6da5c93a3936356934
  4aece1166947a30789459a579d97d2afbe2bada6 1e13fd4ed22de5cb7ff1a9389b00c017e42ab200
  7a1ce9d9ee87c1952fe2b1cb5b0ed2e4235165f7 d40942a9da0d84ae8adf4e1572d9eabd27d14a06
  4295756c3a09f0e40e7a23d3429d1d95913dc8b1 e69973cbef0270438790827a4ee825690450d48c
  d9b1b0cb7c09d8b7967a61efb13e5f4dac6c2e39 4095e1bd6a93189efca27eda3b02a903ed8c0a3f
  43c74ad13a178defaef8ddd501f1492f2ecfff41 dfab2194f3acb558f20e9735d83e5b2694af6005
  46aad6591a56768ebddc4cc03de25a008e4c6525 868092aeba8e9993db9741b22bf16ef692e6a852
  f2453a8119e82fa1010fd7bc0c2adcb2483eb1e2 bf62e62be33d9f33eaa077841358d3a2428bfd22
  ef0a52a36048321627abe8955e71ed33b8dc40ac 562c491922db38d16f2789124a490184bd736494
  c8538173cb7fd54b2d6546f51115caf83b99b524 14c905854aef395446a34997e0761473a69b84dd
  d4976af1c2020c8209c0602714a943b5c6c9e1c6 42e997369389e93d7512cd5bcf47bd77c85e7835
  071a59413d9cb58a5fa275401657311dcebdb387
)
for sha in "${old_shas[@]}"; do
  tags=()
  for service in api web; do
    tag="voice-platform-$service:$sha"
    id="$(docker image inspect --format '{{.Id}}' "$tag")" || fail "old tag is missing: $tag"
    [[ "$id" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "old tag ID is invalid: $tag"
    for protected_id in "${protected_ids[@]}"; do
      [[ "$id" != "$protected_id" ]] || fail "old tag shares a protected image: $tag"
    done
    users="$(docker ps -a -q --filter "ancestor=$tag")" || fail "container lookup failed: $tag"
    [[ -z "$users" ]] || fail "old tag is referenced by a container: $tag"
    tags+=("$tag")
  done
  for tag in "${tags[@]}"; do
    docker image rm --no-prune "$tag" >/dev/null || fail "tag removal failed: $tag"
    printf 'Removed unused release tag: %s\n' "$tag"
  done
  finish_if_ready
done
fail "allowlisted old images did not restore build headroom ($available < $target bytes)"
