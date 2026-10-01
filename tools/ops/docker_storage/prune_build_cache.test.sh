#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
script="$repo/tools/ops/docker_storage/prune_build_cache.sh"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/docker" "$fixture/attachments" \
  "$fixture/releases/9201f219f9c1311a3b58f3bacf040cda00b4029c/scripts"
printf '6123745280\n' > "$fixture/available"

cat > "$fixture/bin/docker" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  'info --format') printf '%s\n' "$TEST_ROOT/docker" ;;
  'volume inspect') printf '%s\n' "$TEST_ROOT/attachments" ;;
  'ps --filter')
    if [[ "$*" == *'service=api'* ]]; then
      printf 'voice-platform-api:4df09bd772acac695290448ba77735f7755a7fa0\n'
    elif [[ "$*" == *'service=web'* ]]; then
      printf 'voice-platform-web:%s\n' "${TEST_WEB_SHA:-4df09bd772acac695290448ba77735f7755a7fa0}"
    fi ;;
  'builder prune')
    [[ "$*" == 'builder prune --all --force' ]] || exit 1
    printf 'prune\n' >> "$TEST_LOG"
    current="$(cat "$TEST_AVAIL_FILE")"
    printf '%s\n' "$((current + TEST_PRUNE_BYTES))" > "$TEST_AVAIL_FILE" ;;
  *) printf 'unexpected Docker call: %s\n' "$*" >&2; exit 1 ;;
esac
EOF
cat > "$fixture/bin/findmnt" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"$TEST_ROOT/docker"* && "${TEST_FS_MISMATCH:-0}" == 1 ]]; then
  printf '/dev/other\n'
else
  printf '/dev/test\n'
fi
EOF
cat > "$fixture/bin/df" <<'EOF'
#!/usr/bin/env bash
printf 'Avail Size\n%s 31591473160\n' "$(cat "$TEST_AVAIL_FILE")"
EOF
mkdir -p "$fixture/releases/9201f219f9c1311a3b58f3bacf040cda00b4029c/tools/ops/attachment_headroom"
cat > "$fixture/releases/9201f219f9c1311a3b58f3bacf040cda00b4029c/tools/ops/attachment_headroom/check-attachment-volume-headroom.sh" <<'EOF'
#!/usr/bin/env bash
printf 'guard\n' >> "$TEST_LOG"
[[ "$(cat "$TEST_AVAIL_FILE")" -ge 6343294632 ]]
EOF
chmod 0755 "$fixture/bin/"* "$fixture/releases/9201f219f9c1311a3b58f3bacf040cda00b4029c/tools/ops/attachment_headroom/"*.sh

run_prune() {
  : > "$fixture/calls"
  PATH="$fixture/bin:$PATH" TEST_ROOT="$fixture" TEST_LOG="$fixture/calls" \
    TEST_AVAIL_FILE="$fixture/available" VOICE_PLATFORM_RELEASE_ROOT="$fixture/releases" \
    TEST_PRUNE_BYTES="${1:-1543000000}" TEST_WEB_SHA="${2:-}" TEST_FS_MISMATCH="${3:-0}" \
    bash "$script" > "$fixture/output" 2>&1
}

run_prune
[[ "$(cat "$fixture/calls")" == $'prune\nguard' ]]
[[ "$(cat "$fixture/available")" -ge 7593294632 ]]

printf '6123745280\n' > "$fixture/available"
if run_prune 1000000000; then
  echo 'insufficient post-prune build headroom was accepted' >&2
  exit 1
fi
[[ "$(cat "$fixture/calls")" == prune ]]

if run_prune 1543000000 bad-web-sha; then
  echo 'changed running image was accepted' >&2
  exit 1
fi
[[ ! -s "$fixture/calls" ]]

if run_prune 1543000000 '' 1; then
  echo 'different backing filesystems were accepted' >&2
  exit 1
fi
[[ ! -s "$fixture/calls" ]]

printf '7593294632\n' > "$fixture/available"
run_prune
[[ "$(cat "$fixture/calls")" == guard ]]
echo 'prune-build-cache safety tests passed'
