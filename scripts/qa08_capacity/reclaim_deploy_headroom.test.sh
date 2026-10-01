#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/docker" "$fixture/attachments"
printf '9500000000\n' > "$fixture/available"

cat > "$fixture/bin/docker" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  'info --format') printf '%s\n' "$TEST_ROOT/docker" ;;
  'volume inspect') printf '%s\n' "$TEST_ROOT/attachments" ;;
  'ps -q')
    case "$*" in
      *'service=api'*) echo aa11 ;;
      *'service=web'*) echo bb22 ;;
      *) exit 2 ;;
    esac ;;
  'ps -aq') printf 'aa11\nbb22\n' ;;
  'inspect --format')
    case "${*: -1}" in
      aa11)
        protected_number=12
        [[ "${TEST_PROTECT_OLD:-0}" == 0 ]] || protected_number=1
        printf 'sha256:%s\n' "$(printf 'voice-platform-api:%040d' "$protected_number" | sha256sum | cut -d' ' -f1)" ;;
      bb22) printf 'sha256:%s\n' "$(printf 'voice-platform-web:%040d' 12 | sha256sum | cut -d' ' -f1)" ;;
      *) exit 2 ;;
    esac ;;
  'builder prune')
    [[ "$*" == 'builder prune --all --force' ]] || exit 2
    echo prune >> "$TEST_LOG"
    printf '10000000000\n' > "$TEST_AVAILABLE" ;;
  'image ls')
    [[ "$*" == 'image ls --format {{.Repository}}:{{.Tag}}' ]] || exit 2
    for n in {1..12}; do printf 'voice-platform-api:%040d\nvoice-platform-web:%040d\n' "$n" "$n"; done ;;
  'image inspect')
    [[ "${3:-}" == --format ]] || exit 0
    format="$4"
    tag="${*: -1}"
    revision="${tag##*:}"
    case "$format" in
      '{{.Created}}') number="${revision: -2}"; printf '2026-09-%02dT00:00:00Z\n' "$((10#$number))" ;;
      '{{.Id}}') printf 'sha256:%s\n' "$(printf '%s' "$tag" | sha256sum | cut -d' ' -f1)" ;;
      '{{index .Config.Labels "org.opencontainers.image.revision"}}') printf '%s\n' "$revision" ;;
      *) exit 2 ;;
    esac ;;
  'image rm')
    [[ "$3" == --no-prune ]] || exit 2
    printf 'remove:%s\n' "$4" >> "$TEST_LOG"
    if [[ "$4" == voice-platform-web:* ]]; then printf '11500000000\n' > "$TEST_AVAILABLE"; fi ;;
  *) printf 'unexpected docker call: %s\n' "$*" >&2; exit 2 ;;
esac
EOF
cat > "$fixture/bin/findmnt" <<'EOF'
#!/usr/bin/env bash
if [[ "${TEST_FS_MISMATCH:-0}" == 1 && "$*" == *'/docker'* ]]; then
  echo /dev/other
else
  echo /dev/test
fi
EOF
cat > "$fixture/bin/df" <<'EOF'
#!/usr/bin/env bash
printf 'Avail Size\n%s 50000000000\n' "$(cat "$TEST_AVAILABLE")"
EOF
chmod +x "$fixture/bin/"*

run_reclaim() {
  : > "$fixture/calls"
  PATH="$fixture/bin:$PATH" TEST_ROOT="$fixture" TEST_LOG="$fixture/calls" \
    TEST_AVAILABLE="$fixture/available" TEST_FS_MISMATCH="${1:-0}" TEST_PROTECT_OLD="${2:-0}" \
    bash "$root/scripts/qa08_capacity/reclaim_deploy_headroom.sh" > "$fixture/output" 2>&1
}

if ! run_reclaim; then cat "$fixture/output" >&2; exit 1; fi
[[ "$(cat "$fixture/calls")" == $'prune\nremove:voice-platform-api:0000000000000000000000000000000000000001\nremove:voice-platform-web:0000000000000000000000000000000000000001' ]]
grep -Fq '11500000000 bytes available' "$fixture/output"

printf '9500000000\n' > "$fixture/available"
if ! run_reclaim 0 1; then cat "$fixture/output" >&2; exit 1; fi
[[ "$(cat "$fixture/calls")" == $'prune\nremove:voice-platform-api:0000000000000000000000000000000000000002\nremove:voice-platform-web:0000000000000000000000000000000000000002' ]]

printf '12000000000\n' > "$fixture/available"
run_reclaim
[[ ! -s "$fixture/calls" ]]

printf '9500000000\n' > "$fixture/available"
if run_reclaim 1; then
  echo 'different backing filesystems were accepted' >&2
  exit 1
fi
[[ ! -s "$fixture/calls" ]]
echo 'deploy headroom recovery safety tests passed'
