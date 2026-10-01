#!/usr/bin/env bash
set -euo pipefail

revision="$1"
source_hash="$2"
binary="$3"
release_dir="$4"
[[ "$revision" =~ ^[0-9a-f]{40}$ && "$source_hash" =~ ^[0-9a-f]{64}$ ]]
[[ "$binary" == "/tmp/voice-platform-buildx-$revision" ]]
[[ "$release_dir" == "/opt/voice-platform-releases/$revision" ]]
expected_binary_hash=9447199cdb435f25880548343c128a4b6650e8891ee598905d8d29d39a8e359b
actual_binary_hash="$(sha256sum "$binary" | awk '{print $1}')"
[[ "$actual_binary_hash" == "$expected_binary_hash" ]] || { echo 'Buildx checksum differs' >&2; exit 1; }

config="$(mktemp -d /tmp/voice-platform-buildx-config.XXXXXXXX)"
cleanup() { rm -rf -- "$config"; }
trap cleanup EXIT
install -d -m 0755 "$config/cli-plugins"
install -m 0755 "$binary" "$config/cli-plugins/docker-buildx"
export DOCKER_CONFIG="$config"
docker buildx version

check_space() {
  bash "$release_dir/scripts/check-attachment-volume-headroom.sh"
  local mountpoint available
  mountpoint="$(docker volume inspect --format '{{.Mountpoint}}' voice-platform_attachments-data)"
  available="$(df -B1 --output=avail -- "$mountpoint" | awk 'NR == 2 { print $1 }')"
  [[ "$available" =~ ^[0-9]+$ ]] && (( 10#$available >= 9000000000 )) || {
    echo 'QA-11 build requires at least 9 GB free on attachment filesystem' >&2
    exit 1
  }
}

check_space
for service in api web; do
  context="$release_dir/backend"
  [[ "$service" == web ]] && context="$release_dir/clients/web"
  image="voice-platform-$service:$revision"
  archive="$release_dir/$service.oci.tar"
  docker buildx build --platform linux/amd64 \
    --label "org.opencontainers.image.revision=$revision" \
    --label "org.voice-platform.source-archive-sha256=$source_hash" \
    --sbom=true --provenance=mode=max \
    --output="type=oci,dest=$archive" --load --tag "$image" "$context"
  image_id="$(docker image inspect --format '{{.Id}}' "$image")"
  python3 "$release_dir/scripts/qa11_release/verify_oci.py" \
    "$archive" "$revision" "$source_hash" "$image_id" > "$release_dir/$service.oci.json"
  archive_bytes="$(stat -c %s "$archive")"
  (( archive_bytes > 0 && archive_bytes <= 2000000000 )) || {
    echo "QA-11 $service OCI archive exceeds 2 GB limit" >&2
    exit 1
  }
  printf '%s OCI index: %s; archive: %s bytes\n' "$service" "$image_id" "$archive_bytes"
  check_space
done
