#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin"
revision=8f5233c8f4c59548d5c6dc4a782f166ac865567b

cat > "$fixture/bin/sudo" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == -n ]] || exit 2
shift
"$@"
EOF
cat > "$fixture/bin/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  'version --format') echo 29.0.0 ;;
  'info --format') echo overlay2 ;;
  'buildx version') [[ "${TEST_BUILDX:-yes}" == yes ]] && echo 'github.com/docker/buildx v0.30.0' ;;
  'buildx ls') echo 'builder docker-container' ;;
  'system df') echo 'Images 2 400MB' ;;
  'volume inspect') echo /tmp/attachments ;;
  'ps --filter')
    if [[ "$*" == *'service=api'* ]]; then echo aaaaaaaaaaaa; else echo bbbbbbbbbbbb; fi ;;
  'inspect --format')
    if [[ "$3" == '{{.Config.Image}}' ]]; then
      if [[ "$4" == aaaaaaaaaaaa ]]; then
        echo "voice-platform-api:$TEST_REVISION"
      else
        echo "voice-platform-web:${TEST_WEB_REVISION:-$TEST_REVISION}"
      fi
    else exit 2; fi ;;
  'image inspect')
    if [[ "$4" == '{{.Size}}' ]]; then echo 200000000
    elif [[ "$4" == '{{.Id}}' ]]; then printf 'sha256:%064d\n' 1
    else exit 2; fi ;;
  *) exit 2 ;;
esac
EOF
cat > "$fixture/bin/df" <<'EOF'
#!/usr/bin/env bash
echo 'Avail Size'
echo '18000000000 32000000000'
echo '18000000000 32000000000'
EOF
chmod 0755 "$fixture/bin/"*

run_preflight() {
  PATH="$fixture/bin:$PATH" TEST_REVISION="$revision" bash "$root/preflight.sh" > "$fixture/output" 2>&1
}

run_preflight
grep -Fq "deployed_revision=$revision" "$fixture/output"
grep -Fq 'buildx_available=yes' "$fixture/output"
grep -Fq 'api_image_size_bytes=200000000' "$fixture/output"
grep -Fq 'web_image_id=sha256:' "$fixture/output"

if TEST_WEB_REVISION=0000000000000000000000000000000000000000 run_preflight; then
  echo 'expected mismatched deployed revisions to fail' >&2
  exit 1
fi
grep -Fq 'Running API and web revisions differ' "$fixture/output"

TEST_BUILDX=no run_preflight
grep -Fq 'buildx_available=no' "$fixture/output"
echo 'QA-11 read-only preflight tests passed'
