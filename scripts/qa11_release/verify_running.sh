#!/usr/bin/env bash
set -euo pipefail
revision="$1"
release_dir="${VOICE_PLATFORM_DIR:-/opt/voice-platform-releases/$revision}"
[[ "$revision" =~ ^[0-9a-f]{40}$ ]]
for service in api web; do
  expected="$(python3 - "$release_dir/$service.oci.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as receipt:
    print(json.load(receipt)["index_digest"])
PY
)"
  [[ "$expected" =~ ^sha256:[0-9a-f]{64}$ ]]
  image="voice-platform-$service:$revision"
  loaded="$(docker image inspect --format '{{.Id}}' "$image")"
  [[ "$loaded" == "$expected" ]] || { echo "$service tag no longer points to verified OCI index" >&2; exit 1; }
  pinned="voice-platform-$service@$expected"
  pinned_id="$(docker image inspect --format '{{.Id}}' "$pinned")"
  [[ "$pinned_id" == "$expected" ]] || { echo "$service digest reference is unavailable" >&2; exit 1; }
  container="$(docker compose --project-directory "$release_dir" -f "$release_dir/compose.yaml" ps -q "$service")"
  [[ -n "$container" ]]
  running="$(docker inspect --format '{{.Image}}' "$container")"
  [[ "$running" == "$expected" ]] || { echo "$service container differs from verified OCI index" >&2; exit 1; }
  configured="$(docker inspect --format '{{.Config.Image}}' "$container")"
  [[ "$configured" == "$pinned" ]] || { echo "$service container does not use the pinned digest reference" >&2; exit 1; }
  printf '%s running OCI index: %s\n' "$service" "$expected"
done
