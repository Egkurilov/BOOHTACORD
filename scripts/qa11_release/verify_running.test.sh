#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin"
revision=8f5233c8f4c59548d5c6dc4a782f166ac865567b
digest="sha256:$(printf '%064d' 1)"
for service in api web; do
  printf '{"index_digest":"%s"}\n' "$digest" > "$fixture/$service.oci.json"
done
touch "$fixture/compose.yaml"
cat > "$fixture/bin/docker" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  'image inspect') echo "$TEST_IMAGE_ID" ;;
  'compose --project-directory') echo "${@: -1}-container" ;;
  'inspect --format')
    if [[ "$3" == '{{.Image}}' ]]; then echo "$TEST_RUNNING_ID"
    elif [[ "$3" == '{{.Config.Image}}' ]]; then echo "voice-platform-${4%-container}@$TEST_IMAGE_ID"
    else exit 2; fi ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$fixture/bin/docker"
cat > "$fixture/bin/python3" <<'EOF'
#!/usr/bin/env bash
exec python "$@"
EOF
chmod +x "$fixture/bin/python3"
export PATH="$fixture/bin:$PATH" VOICE_PLATFORM_DIR="$fixture"
export TEST_IMAGE_ID="$digest" TEST_RUNNING_ID="$digest"
bash "$root/verify_running.sh" "$revision" > "$fixture/output"
grep -q 'api running OCI index' "$fixture/output"
grep -q 'web running OCI index' "$fixture/output"
TEST_RUNNING_ID="sha256:$(printf '%064d' 2)"
export TEST_RUNNING_ID
if bash "$root/verify_running.sh" "$revision" > "$fixture/output" 2>&1; then
  echo 'expected mismatched running container to fail' >&2
  exit 1
fi
grep -q 'container differs from verified OCI index' "$fixture/output"
echo 'QA-11 running digest tests passed'
