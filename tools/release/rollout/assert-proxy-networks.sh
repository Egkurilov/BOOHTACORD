#!/usr/bin/env bash
set -euo pipefail
project_dir="${1:?project directory is required}"
compose_dir="$project_dir"
[[ ! -f "$project_dir/deploy/compose.yaml" ]] || compose_dir="$project_dir/deploy"
proxy_id="$(docker compose --project-directory "$compose_dir" --env-file "$project_dir/.env" -f "$compose_dir/compose.yaml" ps -q proxy)"
[[ -n "$proxy_id" ]] || { echo "Proxy container is unavailable after deployment." >&2; exit 1; }
networks="$(docker inspect --format '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' "$proxy_id" | awk 'NF' | sort | paste -sd' ' -)"
[[ "$networks" == "voice-platform_edge voice-platform_private" ]] || {
  echo "Proxy has an unexpected Docker network attachment." >&2
  exit 1
}
