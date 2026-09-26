#!/usr/bin/env bash
set -euo pipefail
[[ "$GIT_SHA" =~ ^[0-9a-f]{40}$ ]]
[[ "$ARCHIVE_SHA256" =~ ^[0-9a-f]{64}$ ]]
[[ -f "$ARCHIVE" ]]

binary="${RUNNER_TEMP:?}/docker-buildx-v0.37.1"
url=https://github.com/docker/buildx/releases/download/v0.37.1/buildx-v0.37.1.linux-amd64
curl -fL --retry 2 --max-time 90 "$url" -o "$binary"
printf '9447199cdb435f25880548343c128a4b6650e8891ee598905d8d29d39a8e359b  %s\n' "$binary" | sha256sum -c -

remote="${SSH_USER}@${DEPLOY_SERVER_IP}"
remote_archive="/tmp/voice-platform-${GIT_SHA}.tar.gz"
remote_binary="/tmp/voice-platform-buildx-${GIT_SHA}"
ssh_options=(-i "$HOME/.ssh/id_deploy" -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$HOME/.ssh/known_hosts")
scp "${ssh_options[@]}" "$ARCHIVE" "$remote:$remote_archive"
scp "${ssh_options[@]}" "$binary" "$remote:$remote_binary"
ssh "${ssh_options[@]}" "$remote" bash -s -- "$GIT_SHA" "$ARCHIVE_SHA256" < scripts/install-received-release.sh
