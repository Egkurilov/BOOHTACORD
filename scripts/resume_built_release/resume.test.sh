#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root/scripts/resume_built_release/resume.sh"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
sha=0123456789abcdef0123456789abcdef01234567
release_root="$fixture/voice-platform-releases"
release_dir="$release_root/$sha"
mkdir -p "$release_dir/scripts" "$fixture/bin"
printf 'services: {}\n' > "$release_dir/compose.yaml"
printf 'PUBLIC_HOST=example.test\n' > "$release_dir/.env"

cat > "$release_dir/scripts/check-attachment-volume-headroom.sh" <<'EOF'
#!/usr/bin/env bash
printf 'guard\n' >> "$TEST_LOG"
[[ "${TEST_FAIL_GUARD:-0}" != 1 ]]
EOF
cat > "$release_dir/scripts/deploy-images.sh" <<'EOF'
#!/usr/bin/env bash
printf 'deploy:%s:%s:%s\n' "$VOICE_PLATFORM_DIR" "$API_IMAGE" "$WEB_IMAGE" >> "$TEST_LOG"
EOF
cat > "$release_dir/scripts/audit-attachment-volume.sh" <<'EOF'
#!/usr/bin/env bash
printf 'audit:%s\n' "$1" >> "$TEST_LOG"
EOF
cat > "$fixture/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf 'docker:%s\n' "$*" >> "$TEST_LOG"
[[ "$1" == image && "$2" == inspect && "${TEST_MISSING_IMAGE:-0}" != 1 ]]
EOF
chmod 0755 "$fixture/bin/docker" "$release_dir/scripts/"*.sh

run_resume() {
  : > "$fixture/calls"
  TEST_LOG="$fixture/calls" PATH="$fixture/bin:$PATH" \
    VOICE_PLATFORM_RELEASE_ROOT="$release_root" \
    TEST_FAIL_GUARD="${1:-0}" TEST_MISSING_IMAGE="${2:-0}" \
    bash "$script" "$sha" > "$fixture/output" 2>&1
}

run_resume
mapfile -t calls < "$fixture/calls"
[[ "${calls[0]}" == guard ]]
[[ "${calls[1]}" == "docker:image inspect voice-platform-api:$sha" ]]
[[ "${calls[2]}" == "docker:image inspect voice-platform-web:$sha" ]]
[[ "${calls[3]}" == "deploy:$release_dir:voice-platform-api:$sha:voice-platform-web:$sha" ]]
[[ "${calls[4]}" == "audit:$sha" ]]
[[ "${#calls[@]}" -eq 5 ]]

if run_resume 1; then
  echo 'expected guard failure to stop before image lookup and deploy' >&2
  exit 1
fi
[[ "$(cat "$fixture/calls")" == guard ]]

if run_resume 0 1; then
  echo 'expected missing image to stop before deploy' >&2
  exit 1
fi
if grep -q '^deploy:' "$fixture/calls"; then
  echo 'missing image unexpectedly reached deploy' >&2
  exit 1
fi

if TEST_LOG="$fixture/calls" PATH="$fixture/bin:$PATH" \
  VOICE_PLATFORM_RELEASE_ROOT="$release_root" bash "$script" bad-sha > "$fixture/output" 2>&1; then
  echo 'expected invalid SHA to fail' >&2
  exit 1
fi
echo 'resume-built-release tests passed'
