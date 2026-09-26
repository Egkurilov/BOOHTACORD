#!/usr/bin/env bash
set -euo pipefail

incoming="${1:-}"
[[ "$incoming" =~ ^/tmp/voice-platform-qa11-buildx-[0-9a-f]{40}$ ]] || {
  echo 'Invalid temporary Buildx path' >&2
  exit 1
}
expected=9447199cdb435f25880548343c128a4b6650e8891ee598905d8d29d39a8e359b
config=''
cleanup() {
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
