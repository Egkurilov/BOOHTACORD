#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repository_root/scripts/deploy-images.sh"
temporary_root="$(mktemp -d)"
trap 'rm -rf "$temporary_root"' EXIT

project_dir="$temporary_root/project"
bin_dir="$temporary_root/bin"
mkdir -p "$project_dir" "$bin_dir"
printf 'services: {}\n' > "$project_dir/compose.yaml"
cat > "$project_dir/.env" <<'EOF'
PUBLIC_HOST=v.bootybay.ru
API_IMAGE=ghcr.io/example/voice-platform-api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
WEB_IMAGE=ghcr.io/example/voice-platform-web@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
EOF

cat > "$bin_dir/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"

if [[ "$1" == "inspect" ]]; then
  if [[ "${FAKE_NETWORK_MODE:-allowed}" == "extra" ]]; then
    printf '%s\n' fluxer_fluxer voice-platform_edge voice-platform_private
  else
    printf '%s\n' voice-platform_edge voice-platform_private
  fi
  exit 0
fi

if [[ "$1" == "compose" && " $* " == *" ps -q proxy "* ]]; then
  printf '%s\n' proxy-container
fi
EOF
chmod 0755 "$bin_dir/docker"

cat > "$bin_dir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "curl $*" >> "$FAKE_DOCKER_LOG"
[[ "${FAKE_HEALTH_MODE:-allowed}" != "fail" ]]
EOF
chmod 0755 "$bin_dir/curl"

cat > "$bin_dir/sleep" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "sleep $*" >> "$FAKE_DOCKER_LOG"
EOF
chmod 0755 "$bin_dir/sleep"

run_deploy() {
  local network_mode="$1"
  local output="$2"
  FAKE_DOCKER_LOG="$temporary_root/commands-$network_mode.log" \
  FAKE_NETWORK_MODE="$network_mode" \
  FAKE_HEALTH_MODE="${3:-allowed}" \
  PATH="$bin_dir:$PATH" \
  VOICE_PLATFORM_DIR="$project_dir" \
  API_IMAGE="ghcr.io/example/voice-platform-api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
  WEB_IMAGE="ghcr.io/example/voice-platform-web@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" \
  bash "$script" > "$output" 2>&1
}

line_number() {
  local pattern="$1"
  local log_file="$2"
  grep -n -F "$pattern" "$log_file" | head -n 1 | cut -d: -f1
}

allowed_output="$temporary_root/allowed.out"
run_deploy allowed "$allowed_output"
allowed_log="$temporary_root/commands-allowed.log"

enable_line="$(line_number 'maintenance-admission --enable' "$allowed_log")"
wait_line="$(line_number 'sleep 15' "$allowed_log")"
pull_line="$(line_number 'pull api migrate web' "$allowed_log")"
migrate_line="$(line_number 'run --rm --no-deps migrate' "$allowed_log")"
workload_line="$(line_number 'up -d --no-deps --no-build api web' "$allowed_log")"
proxy_line="$(line_number 'up -d --no-deps --no-build --force-recreate proxy' "$allowed_log")"
inspect_line="$(line_number 'inspect --format' "$allowed_log")"
validate_line="$(line_number 'exec -T proxy caddy validate' "$allowed_log")"
health_line="$(line_number 'curl -fsS --retry 5 --retry-connrefused https://v.bootybay.ru/api/v1/health' "$allowed_log")"
disable_line="$(line_number 'maintenance-admission --disable' "$allowed_log")"

[[ "$enable_line" -lt "$wait_line" ]]
[[ "$wait_line" -lt "$pull_line" ]]
[[ "$pull_line" -lt "$migrate_line" ]]
[[ "$migrate_line" -lt "$workload_line" ]]
[[ "$workload_line" -lt "$proxy_line" ]]
[[ "$proxy_line" -lt "$inspect_line" ]]
[[ "$inspect_line" -lt "$validate_line" ]]
[[ "$validate_line" -lt "$health_line" ]]
[[ "$health_line" -lt "$disable_line" ]]

extra_output="$temporary_root/extra.out"
if run_deploy extra "$extra_output"; then
  echo 'expected extra proxy network to fail deployment' >&2
  exit 1
fi
grep -F 'Proxy has an unexpected Docker network attachment.' "$extra_output"
extra_log="$temporary_root/commands-extra.log"
! grep -Fq 'exec -T proxy caddy validate' "$extra_log"
! grep -Fq 'curl -fsS --retry 5 --retry-connrefused https://v.bootybay.ru/api/v1/health' "$extra_log"

health_output="$temporary_root/health.out"
if run_deploy allowed "$health_output" fail; then
  echo 'expected health failure to preserve maintenance admission' >&2
  exit 1
fi
health_log="$temporary_root/commands-allowed.log"
grep -Fq 'maintenance-admission --enable' "$health_log"
! grep -Fq 'maintenance-admission --disable' "$health_log"

echo 'deploy-images tests passed'
