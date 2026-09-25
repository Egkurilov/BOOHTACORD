#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
project="$fixture/project"
mkdir -p "$project/scripts" "$fixture/bin"
printf 'services: {}\n' > "$project/compose.yaml"
printf 'PUBLIC_HOST=v.bootybay.ru\nAPI_IMAGE=old\nWEB_IMAGE=old\n' > "$project/.env"

cat > "$fixture/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf 'docker %s\n' "$*" >> "$TEST_LOG"
if [[ "$1" == compose && " $* " == *' ps -q proxy '* ]]; then printf 'proxy-container\n'; fi
if [[ "$1" == inspect ]]; then printf 'voice-platform_edge\nvoice-platform_private\n'; fi
EOF
cat > "$fixture/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf 'curl\n' >> "$TEST_LOG"
EOF
cat > "$fixture/bin/sleep" <<'EOF'
#!/usr/bin/env bash
printf 'sleep\n' >> "$TEST_LOG"
EOF
cat > "$project/scripts/check-attachment-volume-headroom.sh" <<'EOF'
#!/usr/bin/env bash
printf 'guard\n' >> "$TEST_LOG"
[[ "${TEST_GUARD:-pass}" == pass ]]
EOF
chmod 0755 "$fixture/bin/"* "$project/scripts/check-attachment-volume-headroom.sh"

run_deploy() {
  : > "$fixture/calls"
  TEST_LOG="$fixture/calls" TEST_GUARD="$1" PATH="$fixture/bin:$PATH" \
    VOICE_PLATFORM_DIR="$project" \
    API_IMAGE=ghcr.io/example/voice-platform-api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
    WEB_IMAGE=ghcr.io/example/voice-platform-web@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
    bash "$root/scripts/deploy-images.sh" > "$fixture/output" 2>&1
}

if run_deploy fail; then
  echo 'missing post-pull headroom guard accepted' >&2
  exit 1
fi
[[ "$(cat "$project/.env")" == $'PUBLIC_HOST=v.bootybay.ru\nAPI_IMAGE=old\nWEB_IMAGE=old' ]]
grep -Fq 'pull api migrate web' "$fixture/calls"
grep -Fxq guard "$fixture/calls"
if grep -Fq 'run --rm --no-deps migrate' "$fixture/calls"; then exit 1; fi
if grep -Fq 'up -d --no-deps --no-build api web' "$fixture/calls"; then exit 1; fi
grep -Fq 'maintenance-admission --disable' "$fixture/calls"

run_deploy pass
pull="$(grep -n -F 'pull api migrate web' "$fixture/calls" | head -n 1 | cut -d: -f1)"
guard="$(grep -n -Fx guard "$fixture/calls" | head -n 1 | cut -d: -f1)"
migrate="$(grep -n -F 'run --rm --no-deps migrate' "$fixture/calls" | head -n 1 | cut -d: -f1)"
[[ "$pull" -lt "$guard" && "$guard" -lt "$migrate" ]]
echo 'registry pull headroom guard tests passed'
