#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo 'Compose CI binary requires Linux x86_64' >&2
  exit 1
fi
binary="$(mktemp "${RUNNER_TEMP:-/tmp}/docker-compose.XXXXXX")"
trap 'rm -f "$binary"' ERR
wget -q 'https://github.com/docker/compose/releases/download/v5.5.0/docker-compose-linux-x86_64' -O "$binary"
echo 'c57ab918abd5b05ca7e7d0f275875dd1330a695074f309dc9eab1b49efafcd4b  '"$binary" | sha256sum -c - >&2
chmod +x "$binary"
printf '%s\n' "$binary"
