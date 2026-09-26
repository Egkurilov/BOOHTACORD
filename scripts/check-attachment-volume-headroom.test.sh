#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
guard="$root/scripts/check-attachment-volume-headroom.sh"
release="$root/scripts/install-received-release.sh"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/attachments"

cat > "$fixture/bin/docker" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == 'volume inspect --format {{.Mountpoint}} voice-platform_attachments-data' ]] || exit 2
[[ "${TEST_VOLUME_MODE:-ok}" != fail ]] || exit 1
printf '%s\n' "$TEST_MOUNTPOINT"
EOF
cat > "$fixture/bin/df" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == -B1 && "$2" == --output=avail,size && "$3" == -- && "$4" == "$TEST_MOUNTPOINT" ]] || exit 2
[[ "${TEST_DF_MODE:-ok}" != fail ]] || exit 1
printf 'Avail Size\n%s %s\n' "$TEST_AVAILABLE" "$TEST_TOTAL"
EOF
chmod 0755 "$fixture/bin/docker" "$fixture/bin/df"

run_guard() {
  PATH="$fixture/bin:$PATH" TEST_MOUNTPOINT="$fixture/attachments" \
    TEST_AVAILABLE="$1" TEST_TOTAL="$2" \
    TEST_VOLUME_MODE="${3:-ok}" TEST_DF_MODE="${4:-ok}" \
    bash "$guard" > "$fixture/output" 2>&1
}

# 31,591,473,152 B filesystem: 10% ceiling twice, plus one 25 MB upload.
required=6343294632
run_guard "$required" 31591473152
if run_guard "$((required - 1))" 31591473152; then
  echo 'expected one byte below pre-build threshold to fail' >&2
  exit 1
fi
grep -Fq 'insufficient attachment volume headroom' "$fixture/output"

# On a smaller filesystem the 2 GiB floor controls each of the two buffers.
run_guard 4319967296 10000000000
if run_guard 4319967295 10000000000; then
  echo 'expected 2 GiB floor to reject insufficient headroom' >&2
  exit 1
fi
if run_guard 7000000000 31591473152 fail; then
  echo 'expected missing volume to fail closed' >&2
  exit 1
fi
if run_guard 7000000000 31591473152 ok fail; then
  echo 'expected unknown df result to fail closed' >&2
  exit 1
fi
if run_guard unknown 31591473152; then
  echo 'expected malformed df result to fail closed' >&2
  exit 1
fi

mapfile -t guard_lines < <(grep -nF 'check-attachment-volume-headroom.sh' "$release" | cut -d: -f1)
promote_line="$(grep -nF 'sudo -n mv ' "$release" | cut -d: -f1)"
build_line="$(grep -nF 'qa11_release/build_images.sh' "$release" | cut -d: -f1)"
deploy_line="$(grep -nF 'deploy-images.sh' "$release" | cut -d: -f1)"
[[ "${#guard_lines[@]}" -eq 2 && -n "$promote_line" && -n "$build_line" && -n "$deploy_line" ]]
[[ "${guard_lines[0]}" -lt "$promote_line" && "$promote_line" -lt "$build_line" ]]
[[ "$build_line" -lt "${guard_lines[1]}" && "${guard_lines[1]}" -lt "$deploy_line" ]]
echo 'attachment volume pre/post-build guard tests passed'
