#!/usr/bin/env bash
set -euo pipefail
git_sha="$1"
expected_archive_sha256="$2"
[[ "$git_sha" =~ ^[0-9a-f]{40}$ ]]
[[ "$expected_archive_sha256" =~ ^[0-9a-f]{64}$ ]]
archive="/tmp/voice-platform-${git_sha}.tar.gz"
release_root=/opt/voice-platform-releases
release_dir="${release_root}/${git_sha}"
staging_dir=''
cleanup() {
  rm -f -- "$archive"
  if [[ -n "$staging_dir" && "$staging_dir" == "$release_root"/.incoming.* ]]; then
    sudo -n rm -rf -- "$staging_dir"
  fi
}
trap cleanup EXIT
actual_archive_sha256="$(sha256sum "$archive" | awk '{print $1}')"
[[ "$actual_archive_sha256" == "$expected_archive_sha256" ]]
sudo -n install -d -m 0750 "$release_root"
[[ ! -e "$release_dir" ]]
staging_dir="$(sudo -n mktemp -d "${release_root}/.incoming.XXXXXXXX")"
sudo -n tar -xzf "$archive" -C "$staging_dir"
sudo -n install -m 0600 /opt/voice-platform/.env "$staging_dir/.env"
sudo -n mv "$staging_dir" "$release_dir"
staging_dir=''
api_image="voice-platform-api:${git_sha}"
web_image="voice-platform-web:${git_sha}"
sudo -n env API_IMAGE="$api_image" WEB_IMAGE="$web_image" docker compose --project-directory "$release_dir" -f "$release_dir/compose.yaml" build api web
sudo -n env VOICE_PLATFORM_DIR="$release_dir" API_IMAGE="$api_image" WEB_IMAGE="$web_image" bash "$release_dir/scripts/deploy-images.sh"
