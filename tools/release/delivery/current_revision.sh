#!/usr/bin/env bash
set -euo pipefail
current=''
for service in api web; do
  container="$(docker ps --filter label=com.docker.compose.project=voice-platform --filter "label=com.docker.compose.service=$service" --format '{{.ID}}')"
  [[ "$container" =~ ^[0-9a-f]+$ ]]
  revision="$(docker inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$container")"
  if [[ ! "$revision" =~ ^[0-9a-f]{40}$ ]]; then
    image="$(docker inspect --format '{{.Image}}' "$container")"
    revision="$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$image")"
  fi
  [[ "$revision" =~ ^[0-9a-f]{40}$ ]]
  [[ -z "$current" || "$current" == "$revision" ]]
  current="$revision"
done
printf '%s\n' "$current"
