#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
script="$repository_root/tools/release/rollout/deploy-images.sh"
temporary_root="$(mktemp -d)"
trap 'rm -rf "$temporary_root"' EXIT

project_dir="$temporary_root/project"
bin_dir="$temporary_root/bin"
mkdir -p "$project_dir/scripts" "$bin_dir"
mkdir -p "$project_dir/tools/ops/attachment_headroom"
printf '#!/usr/bin/env bash\nexit 0\n' > "$project_dir/tools/ops/attachment_headroom/check-attachment-volume-headroom.sh"
printf 'services: {}\n' > "$project_dir/compose.yaml"
printf 'PUBLIC_HOST=v.bootybay.ru\n' > "$project_dir/.env"

cat > "$bin_dir/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"
if [[ "$1" == "image" && "$2" == "inspect" ]]; then
  [[ "${FAKE_LOCAL_IMAGES:-missing}" == "available" ]]
elif [[ "$1" == "inspect" ]]; then
  printf '%s\n' voice-platform_edge voice-platform_private
elif [[ "$1" == "compose" && " $* " == *" ps -q proxy "* ]]; then
  printf '%s\n' proxy-container
fi
EOF
cat > "$bin_dir/python3" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'python3 %s\n' "$*" >> "$FAKE_DOCKER_LOG"
EOF
printf '#!/usr/bin/env bash\nexit 0\n' > "$bin_dir/curl"
printf '#!/usr/bin/env bash\nexit 0\n' > "$bin_dir/sleep"
chmod 0755 "$bin_dir/docker" "$bin_dir/python3" "$bin_dir/curl" "$bin_dir/sleep"

api_image="voice-platform-api:0123456789abcdef0123456789abcdef01234567"
web_image="voice-platform-web:0123456789abcdef0123456789abcdef01234567"

run_deploy() {
  FAKE_DOCKER_LOG="$temporary_root/commands.log" \
  FAKE_LOCAL_IMAGES="${1:-available}" \
  PATH="$bin_dir:$PATH" \
  VOICE_PLATFORM_DIR="$project_dir" \
  API_IMAGE="${2:-$api_image}" \
  WEB_IMAGE="${3:-$web_image}" \
  bash "$script" > "$temporary_root/output" 2>&1
}

run_deploy
grep -Fq -- '--ensure-postgres-alias' "$temporary_root/commands.log"
grep -Fq "image inspect $api_image" "$temporary_root/commands.log"
grep -Fq "image inspect $web_image" "$temporary_root/commands.log"
if grep -Fq 'pull api migrate web' "$temporary_root/commands.log"; then exit 1; fi

if run_deploy available "$api_image" "voice-platform-web:fedcba9876543210fedcba9876543210fedcba98"; then
  echo 'expected mismatched local image revisions to fail' >&2
  exit 1
fi
grep -Fq 'Local API and web images must use the same commit revision.' "$temporary_root/output"

if run_deploy missing; then
  echo 'expected missing local images to fail' >&2
  exit 1
fi
grep -Fq 'Local API image is unavailable.' "$temporary_root/output"

api_digest="voice-platform-api@sha256:$(printf '%064d' 1)"
web_digest="voice-platform-web@sha256:$(printf '%064d' 2)"
run_deploy available "$api_digest" "$web_digest"
grep -Fq "image inspect $api_digest" "$temporary_root/commands.log"
grep -Fq "image inspect $web_digest" "$temporary_root/commands.log"
[[ "$(grep -Fc -- '--ensure-postgres-alias' "$temporary_root/commands.log")" == 2 ]]
if grep -Fq 'pull api migrate web' "$temporary_root/commands.log"; then exit 1; fi

echo 'deploy-local-images tests passed'
