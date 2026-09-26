#!/usr/bin/env bash
set -euo pipefail

incoming="${1:-}"
[[ "$incoming" =~ ^/tmp/voice-platform-qa11-buildx-[0-9a-f]{40}$ ]] || {
  echo 'Invalid temporary Buildx path' >&2
  exit 1
}
expected=9447199cdb435f25880548343c128a4b6650e8891ee598905d8d29d39a8e359b
config=''
probe_image="voice-platform-qa11-probe:${incoming##*-}"
cleanup() {
  sudo -n docker image rm -- "$probe_image" >/dev/null 2>&1 || true
  if [[ "$config" == /tmp/voice-platform-qa11-config.* ]]; then
    sudo -n rm -rf -- "$config"
  fi
  rm -f -- "$incoming"
}
trap cleanup EXIT
actual="$(sha256sum "$incoming" | awk '{print $1}')"
[[ "$actual" == "$expected" ]] || { echo 'Buildx checksum differs' >&2; exit 1; }

config="$(sudo -n mktemp -d /tmp/voice-platform-qa11-config.XXXXXXXX)"
sudo -n install -d -m 0755 "$config/cli-plugins"
sudo -n install -m 0755 "$incoming" "$config/cli-plugins/docker-buildx"
sudo -n env DOCKER_CONFIG="$config" docker buildx version
sudo -n env DOCKER_CONFIG="$config" docker buildx ls

mountpoint="$(sudo -n docker volume inspect --format '{{.Mountpoint}}' voice-platform_attachments-data)"
[[ "$mountpoint" == /* ]] || { echo 'Attachment volume mountpoint is invalid' >&2; exit 1; }
available="$(sudo -n df -B1 --output=avail -- "$mountpoint" | awk 'NR == 2 { print $1 }')"
[[ "$available" =~ ^[0-9]+$ ]] || { echo 'Available bytes are invalid' >&2; exit 1; }
(( 10#$available > 9000000000 )) || { echo 'Insufficient space for the QA-11 probe' >&2; exit 1; }

sudo -n install -d -m 0755 "$config/context"
printf 'FROM scratch\nCOPY marker /marker\n' | sudo -n tee "$config/context/Dockerfile" >/dev/null
printf 'QA-11 build probe\n' | sudo -n tee "$config/context/marker" >/dev/null
if sudo -n env DOCKER_CONFIG="$config" docker buildx build \
  --platform linux/amd64 --sbom=true --provenance=mode=max \
  --output="type=oci,dest=$config/probe.oci.tar" \
  --metadata-file="$config/build-metadata.json" "$config/context"; then
  printf 'default_driver_oci_export=yes\n'
  sudo -n ls -l "$config/probe.oci.tar" "$config/build-metadata.json"
else
  printf 'default_driver_oci_export=no\n'
fi

if sudo -n env DOCKER_CONFIG="$config" docker buildx build \
  --platform linux/amd64 --sbom=true --provenance=mode=max \
  --output="type=oci,dest=$config/probe-dual.oci.tar" \
  --load --tag "$probe_image" "$config/context"; then
  printf 'default_driver_dual_export=yes\n'
  printf 'probe_image_id=%s\n' "$(sudo -n docker image inspect --format '{{.Id}}' "$probe_image")"
  sudo -n ls -l "$config/probe-dual.oci.tar"
else
  printf 'default_driver_dual_export=no\n'
fi
