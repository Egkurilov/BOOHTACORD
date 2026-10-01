#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/bundles"
export RELEASE_REVISION=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
export CURRENT_REVISION=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
export BUNDLE_DIRECTORY="$fixture/bundles" RUNNER_TEMP="$fixture" TEST_LOG="$fixture/log"
export SSH_USER=operator DEPLOY_SERVER_IP=127.0.0.1
bundle="$BUNDLE_DIRECTORY/$RELEASE_REVISION.release.tar.gz"
printf 'signed payload fixture\n' > "$bundle"
sha256sum "$bundle" > "$bundle.sha256"
cat > "$fixture/bin/git" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  rev-parse) printf '%s\n' "$RELEASE_REVISION" ;;
  archive) for arg do [[ "$arg" != --output=* ]] || printf 'trusted driver fixture' > "${arg#--output=}"; done ;;
  merge-base) [[ "${REVERSE_HISTORY:-0}" != 1 ]] ;;
  *) exit 90 ;;
esac
EOF
cat > "$fixture/bin/ssh" <<'EOF'
#!/usr/bin/env bash
printf 'ssh %s\n' "$*" >> "$TEST_LOG"
if [[ "$*" != *'bash -s -- '* ]]; then printf '%s\n' "$CURRENT_REVISION"; fi
cat > /dev/null
EOF
cat > "$fixture/bin/scp" <<'EOF'
#!/usr/bin/env bash
printf 'scp %s\n' "$*" >> "$TEST_LOG"
EOF
chmod +x "$fixture/bin/"*
export PATH="$fixture/bin:$PATH"
cd "$root"
bash tools/release/delivery/transfer.sh
[[ "$(grep -c '^scp ' "$TEST_LOG")" == 2 ]]
grep -Fq -- "-- $RELEASE_REVISION" "$TEST_LOG"
grep -Fq -- "$CURRENT_REVISION" "$TEST_LOG"
: > "$TEST_LOG"
if REVERSE_HISTORY=1 bash tools/release/delivery/transfer.sh; then exit 1; fi
! grep -q '^scp ' "$TEST_LOG"
: > "$TEST_LOG"
printf 'tamper\n' >> "$bundle"
if bash tools/release/delivery/transfer.sh; then exit 1; fi
[[ ! -s "$TEST_LOG" ]]
echo 'Signed delivery checksum and forward-history guard tests passed'
