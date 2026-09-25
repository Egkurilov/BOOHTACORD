#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
audit="$root/scripts/audit-attachment-volume.sh"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/attachments"
sha=42e997369389e93d7512cd5bcf47bd77c85e7835

cat > "$fixture/bin/sudo" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == -n ]] || exit 2
shift
"$@"
EOF
cat > "$fixture/bin/docker" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == volume && "$2" == inspect ]]; then
  [[ "${TEST_VOLUME_MODE:-ok}" != fail ]] || exit 1
  printf '%s\n' "$TEST_MOUNTPOINT"
elif [[ "$1" == ps ]]; then
  printf '%s\n' abcdef123456
elif [[ "$1" == inspect && "$2" == --format ]]; then
  if [[ "$3" == '{{.Config.Image}}' ]]; then
    printf '%s\n' "$TEST_API_IMAGE"
  else
    printf '%s\n' 172.20.0.3
  fi
else
  exit 2
fi
EOF
cat > "$fixture/bin/df" <<'EOF'
#!/usr/bin/env bash
printf 'Avail Size\n%s %s\n' "$TEST_AVAILABLE" 31591473152
EOF
cat > "$fixture/bin/findmnt" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '/dev/vda2 ext4 /'
EOF
cat > "$fixture/bin/curl" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *'/metrics' ]]; then
  printf 'voice_platform_attachment_filesystem_available_bytes %s\n' "${TEST_METRIC_AVAILABLE:-6.582e+09}"
  printf 'voice_platform_attachment_filesystem_total_bytes %s\n' "${TEST_METRIC_TOTAL:-3.1591473152e+10}"
  printf 'voice_platform_attachment_filesystem_snapshot_success %s\n' "${TEST_SNAPSHOT:-1}"
  [[ "${TEST_METRICS_MODE:-ok}" == missing ]] || printf '%s\n' 'voice_platform_attachment_upload_reserved_bytes 2.5e+07'
else
  printf '%s\n' '{"status":"ok"}'
fi
EOF
chmod 0755 "$fixture/bin/"*

run_audit() {
  PATH="$fixture/bin:$PATH" TEST_MOUNTPOINT="$fixture/attachments" \
    TEST_API_IMAGE="${3:-voice-platform-api:$sha}" TEST_AVAILABLE="$1" \
    TEST_VOLUME_MODE="${4:-ok}" TEST_METRICS_MODE="${2:-ok}" \
    bash "$audit" "$sha" > "$fixture/output" 2>&1
}

run_audit 6582484992 ok
grep -Fq 'available_bytes=6582484992' "$fixture/output"
grep -Fq 'reserved_bytes=25000000' "$fixture/output"
grep -Fq 'api_health=ok' "$fixture/output"
grep -Fq 'api_image=voice-platform-api:' "$fixture/output"

if run_audit 6000000000 ok; then
  echo 'expected insufficient current headroom to fail' >&2
  exit 1
fi
if run_audit 6582484992 missing; then
  echo 'expected absent reservation gauge to fail' >&2
  exit 1
fi
if run_audit 6582484992 ok voice-platform-api:deadbeef; then
  echo 'expected wrong deployed image to fail' >&2
  exit 1
fi
if run_audit 6582484992 ok "voice-platform-api:$sha" fail; then
  echo 'expected missing volume to fail' >&2
  exit 1
fi
if TEST_METRIC_AVAILABLE=6.0e+09 run_audit 6582484992 ok; then
  echo 'expected insufficient API-reported headroom to fail' >&2
  exit 1
fi
if TEST_METRIC_TOTAL=3.0e+10 run_audit 6582484992 ok; then
  echo 'expected filesystem mismatch to fail' >&2
  exit 1
fi
if TEST_SNAPSHOT=0 run_audit 6582484992 ok; then
  echo 'expected failed snapshot to fail' >&2
  exit 1
fi

echo 'read-only attachment capacity audit tests passed'
