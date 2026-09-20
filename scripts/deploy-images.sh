#!/usr/bin/env bash
set -euo pipefail

project_dir="${VOICE_PLATFORM_DIR:-/opt/voice-platform}"
compose_file="$project_dir/compose.yaml"
env_file="$project_dir/.env"

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

require_digest_image() {
  local name="$1"
  local image="$2"
  [[ -n "$image" ]] || fail "$name is required."
  [[ "$image" == */* && "$image" == *@sha256:* ]] || fail "$name must be a registry digest reference."
  [[ "$image" != *:latest && "$image" != *:latest@* ]] || fail "$name must not use latest."
}

api_image="${API_IMAGE:-}"
web_image="${WEB_IMAGE:-}"
require_digest_image API_IMAGE "$api_image"
require_digest_image WEB_IMAGE "$web_image"
[[ -r "$env_file" ]] || fail "Deployment environment file is unavailable."
public_host="$(sed -n 's/^PUBLIC_HOST=//p' "$env_file" | tail -n 1)"
[[ "$public_host" =~ ^[A-Za-z0-9.-]+$ ]] || fail "PUBLIC_HOST must be a hostname."

compose=(docker compose --project-directory "$project_dir" -f "$compose_file")

assert_proxy_networks() {
  local proxy_id
  local index
  local expected_proxy_networks=(voice-platform_edge voice-platform_private)
  local proxy_networks=()

  proxy_id="$("${compose[@]}" ps -q proxy)"
  [[ -n "$proxy_id" ]] || fail "Proxy container is unavailable after deployment."
  mapfile -t proxy_networks < <(docker inspect --format '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' "$proxy_id" | sort)

  [[ "${#proxy_networks[@]}" -eq "${#expected_proxy_networks[@]}" ]] || fail "Proxy has an unexpected Docker network attachment."
  for index in "${!expected_proxy_networks[@]}"; do
    [[ "${proxy_networks[$index]}" == "${expected_proxy_networks[$index]}" ]] || fail "Proxy has an unexpected Docker network attachment."
  done
}

"${compose[@]}" --profile operator run --rm --no-deps maintenance-admission --enable
sleep 15
API_IMAGE="$api_image" WEB_IMAGE="$web_image" "${compose[@]}" pull api migrate web

umask 077
temporary_env="$(mktemp "$env_file.release.XXXXXX")"
trap 'rm -f "$temporary_env"' EXIT
awk '!/^(API_IMAGE|WEB_IMAGE)=/' "$env_file" > "$temporary_env"
printf 'API_IMAGE=%s\nWEB_IMAGE=%s\n' "$api_image" "$web_image" >> "$temporary_env"
install -m 600 "$temporary_env" "$env_file"
rm -f "$temporary_env"
trap - EXIT

"${compose[@]}" run --rm --no-deps migrate
"${compose[@]}" up -d --no-deps --no-build api web
"${compose[@]}" up -d --no-deps --no-build --force-recreate proxy
assert_proxy_networks
"${compose[@]}" exec -T proxy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
curl -fsS --retry 5 --retry-connrefused "https://${public_host}/api/v1/health"
"${compose[@]}" --profile operator run --rm --no-deps maintenance-admission --disable
