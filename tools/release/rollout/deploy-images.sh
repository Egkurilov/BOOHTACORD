#!/usr/bin/env bash
set -euo pipefail

project_dir="${VOICE_PLATFORM_DIR:-/opt/voice-platform}"
compose_dir="$project_dir"
[[ ! -f "$project_dir/deploy/compose.yaml" ]] || compose_dir="$project_dir/deploy"
compose_file="$compose_dir/compose.yaml"
env_file="$project_dir/.env"

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

api_image="${API_IMAGE:-}"
web_image="${WEB_IMAGE:-}"
[[ -n "$api_image" ]] || fail "API_IMAGE is required."
[[ -n "$web_image" ]] || fail "WEB_IMAGE is required."

if [[ "$api_image" =~ ^voice-platform-api:([0-9a-f]{40})$ ]]; then
  api_revision="${BASH_REMATCH[1]}"
  [[ "$web_image" =~ ^voice-platform-web:([0-9a-f]{40})$ ]] || fail "Images must be matching local commit tags or registry digest references without latest."
  web_revision="${BASH_REMATCH[1]}"
  [[ "$api_revision" == "$web_revision" ]] || fail "Local API and web images must use the same commit revision."
  release_mode="local-build"
elif [[ "$api_image" =~ ^voice-platform-api@sha256:[0-9a-f]{64}$ && "$web_image" =~ ^voice-platform-web@sha256:[0-9a-f]{64}$ ]]; then
  release_mode="local-build"
elif [[ "$api_image" == */* && "$api_image" == *@sha256:* && "$web_image" == */* && "$web_image" == *@sha256:* && "$api_image" != *:latest@* && "$web_image" != *:latest@* ]]; then
  release_mode="registry-digest"
else
  fail "Images must be matching local commit tags or registry digest references without latest."
fi
[[ -r "$env_file" ]] || fail "Deployment environment file is unavailable."
public_host="$(sed -n 's/^PUBLIC_HOST=//p' "$env_file" | tail -n 1)"
[[ "$public_host" =~ ^[A-Za-z0-9.-]+$ ]] || fail "PUBLIC_HOST must be a hostname."

compose=(docker compose --project-directory "$compose_dir" --env-file "$env_file" -f "$compose_file")

assert_proxy_networks() {
  local proxy_id
  local index
  local expected_proxy_networks=(voice-platform_edge voice-platform_private)
  local proxy_networks=()

  proxy_id="$("${compose[@]}" ps -q proxy)"
  [[ -n "$proxy_id" ]] || fail "Proxy container is unavailable after deployment."
  mapfile -t proxy_networks < <(docker inspect --format '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' "$proxy_id" | awk 'NF' | sort)

  [[ "${#proxy_networks[@]}" -eq "${#expected_proxy_networks[@]}" ]] || fail "Proxy has an unexpected Docker network attachment."
  for index in "${!expected_proxy_networks[@]}"; do
    [[ "${proxy_networks[$index]}" == "${expected_proxy_networks[$index]}" ]] || fail "Proxy has an unexpected Docker network attachment."
  done
}

if [[ "$release_mode" == "local-build" ]]; then
  docker image inspect "$api_image" >/dev/null || fail "Local API image is unavailable."
  docker image inspect "$web_image" >/dev/null || fail "Local web image is unavailable."
fi

admission_enabled=0
temporary_env=''

disable_maintenance_admission() {
  if ! "${compose[@]}" up -d --wait postgres; then
    return 1
  fi
  if ! "${compose[@]}" --profile operator run --rm --no-deps maintenance-admission --disable; then
    return 1
  fi
  admission_enabled=0
}

cleanup() {
  local status=$?
  [[ -z "$temporary_env" ]] || rm -f "$temporary_env"
  if [[ "$admission_enabled" -eq 1 ]] && ! disable_maintenance_admission; then
    printf '%s\n' "Could not disable maintenance admission after a failed deployment." >&2
    status=1
  fi
  trap - EXIT
  exit "$status"
}
trap cleanup EXIT

"${compose[@]}" up -d --wait postgres
if ! "${compose[@]}" --profile operator run --rm --no-deps maintenance-admission --enable; then
  python3 "$project_dir/tools/release/rollout/reconcile-postgres-credential.py" "$project_dir"
  "${compose[@]}" --profile operator run --rm --no-deps maintenance-admission --enable
fi
admission_enabled=1
sleep 15
if [[ "$release_mode" == "registry-digest" ]]; then
  API_IMAGE="$api_image" WEB_IMAGE="$web_image" "${compose[@]}" pull api migrate web
fi
bash "$project_dir/tools/ops/attachment_headroom/check-attachment-volume-headroom.sh"

umask 077
temporary_env="$(mktemp "$env_file.release.XXXXXX")"
awk '!/^(API_IMAGE|WEB_IMAGE)=/' "$env_file" > "$temporary_env"
printf 'API_IMAGE=%s\nWEB_IMAGE=%s\n' "$api_image" "$web_image" >> "$temporary_env"
install -m 600 "$temporary_env" "$env_file"
rm -f "$temporary_env"
temporary_env=''

"${compose[@]}" up -d --wait postgres
"${compose[@]}" run --rm --no-deps migrate
"${compose[@]}" up -d --no-deps --no-build api web
"${compose[@]}" up -d --no-deps --no-build --force-recreate proxy
assert_proxy_networks
"${compose[@]}" exec -T proxy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
curl -fsS --retry 5 --retry-connrefused "https://${public_host}/api/v1/health"
disable_maintenance_admission
