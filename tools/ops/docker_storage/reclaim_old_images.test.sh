#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
script="$repo/tools/ops/docker_storage/reclaim_old_images.sh"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/docker" "$fixture/attachments" \
  "$fixture/releases/9201f219f9c1311a3b58f3bacf040cda00b4029c/scripts"
printf '5606207488\n' > "$fixture/available"

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
  'ps -aq') printf 'container1\n' ;;
  'ps -a') [[ "${TEST_IN_USE:-0}" != 1 ]] || printf 'container1\n' ;;
  'inspect --format')
    printf 'sha256:%s\n' "$(printf '%s' 'voice-platform-api:4df09bd772acac695290448ba77735f7755a7fa0' | sha256sum | cut -d' ' -f1)" ;;
  'image inspect')
    tag="${*: -1}"
    if [[ "${TEST_MISSING_WEB:-0}" == 1 && "$tag" == voice-platform-web:a904b2afd92bd153caa60a768383701b4088ca46 ]]; then
      exit 1
    fi
    if [[ "${TEST_SHARED:-0}" == 1 && "$tag" == voice-platform-api:a904b2afd92bd153caa60a768383701b4088ca46 ]]; then
      tag='voice-platform-api:4df09bd772acac695290448ba77735f7755a7fa0'
    fi
    printf 'sha256:%s\n' "$(printf '%s' "$tag" | sha256sum | cut -d' ' -f1)" ;;
  'image rm')
    tag="${*: -1}"
    printf 'remove:%s\n' "$tag" >> "$TEST_LOG"
    current="$(cat "$TEST_AVAIL_FILE")"
    printf '%s\n' "$((current + 500000000))" > "$TEST_AVAIL_FILE" ;;
  *) printf 'unexpected docker call: %s\n' "$*" >&2; exit 1 ;;
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

run_reclaim() {
  : > "$fixture/calls"
  PATH="$fixture/bin:$PATH" TEST_ROOT="$fixture" TEST_LOG="$fixture/calls" \
    TEST_AVAIL_FILE="$fixture/available" VOICE_PLATFORM_RELEASE_ROOT="$fixture/releases" \
    TEST_WEB_SHA="${1:-}" TEST_FS_MISMATCH="${2:-0}" TEST_SHARED="${3:-0}" TEST_IN_USE="${4:-0}" TEST_MISSING_WEB="${5:-0}" \
    bash "$script" > "$fixture/output" 2>&1
}

run_reclaim
[[ "$(grep -c '^remove:' "$fixture/calls")" -eq 4 ]]
grep -q '^guard$' "$fixture/calls"
if grep -Eq 'remove:voice-platform-(api|web):(4df09bd|4ce70a|9201f21)' "$fixture/calls"; then
  echo 'a protected image was removed' >&2
  exit 1
fi

printf '5606207488\n' > "$fixture/available"
if run_reclaim bad-web-sha; then
  echo 'unexpectedly accepted a changed running image' >&2
  exit 1
fi
! grep -q '^remove:' "$fixture/calls" || { echo 'removed an image after running-image mismatch' >&2; exit 1; }

if run_reclaim '' 1; then
  echo 'unexpectedly accepted different backing filesystems' >&2
  exit 1
fi
! grep -q '^remove:' "$fixture/calls" || { echo 'removed an image after filesystem mismatch' >&2; exit 1; }

if run_reclaim '' 0 1; then
  echo 'unexpectedly removed a tag sharing the running image ID' >&2
  exit 1
fi
! grep -q '^remove:' "$fixture/calls" || { echo 'removed a protected image ID' >&2; exit 1; }

if run_reclaim '' 0 0 1; then
  echo 'unexpectedly removed an image referenced by a container' >&2
  exit 1
fi
! grep -q '^remove:' "$fixture/calls" || { echo 'removed a container image' >&2; exit 1; }

if run_reclaim '' 0 0 0 1; then
  echo 'unexpectedly accepted an incomplete image pair' >&2
  exit 1
fi
! grep -q '^remove:' "$fixture/calls" || { echo 'removed half of an incomplete pair' >&2; exit 1; }
echo 'reclaim-old-images safety tests passed'
