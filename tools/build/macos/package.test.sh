#!/usr/bin/env bash
set -euo pipefail

script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/package.sh"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

app="$fixture/BOOHTACORD.app"
mkdir -p "$app/Contents"
printf 'bundle\n' > "$app/Contents/Info.plist"
mkdir -p "$app/Contents/MacOS"
touch "$app/Contents/MacOS/BOOHTACORD"
mkdir -p "$fixture/bin"
cat > "$fixture/bin/codesign" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  --verify)
    [[ "$*" == "--verify --deep --strict --verbose=2 "* ]]
    if [[ "${MOCK_VERIFY_ALWAYS_FAIL:-}" == '1' ]]; then exit 1; fi
    if [[ "${MOCK_VERIFY_FAIL_UNTIL_RESEALED:-}" == '1' && ! -e "$MOCK_RESEALED_MARKER" ]]; then exit 1; fi
    ;;
  -dv)
    printf 'Signature=%s\n' "${MOCK_SIGNATURE:-adhoc}"
    ;;
  --force)
    [[ "$*" == '--force --sign - --preserve-metadata=entitlements,flags,runtime '* ]]
    touch "$MOCK_RESEALED_MARKER"
    ;;
  *) exit 1 ;;
esac
EOF
cat > "$fixture/bin/plutil" <<'EOF'
#!/usr/bin/env bash
case "$2" in
  CFBundleShortVersionString) printf '%s\n' "${MOCK_BUNDLE_VERSION:-1.2.3}" ;;
  CFBundleExecutable) printf '%s\n' BOOHTACORD ;;
  *) exit 1 ;;
esac
EOF
cat > "$fixture/bin/lipo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'x86_64 arm64'
EOF
cat > "$fixture/bin/ditto" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == "-c" && "$2" == "-k" ]]
touch "${@: -1}"
EOF
cat > "$fixture/bin/stat" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == '-f' && "$2" == '%z' ]] || exit 1
wc -c < "$3"
EOF
export STAT="$fixture/bin/stat"
chmod +x "$fixture/bin/stat" "$fixture/bin/codesign" "$fixture/bin/plutil" "$fixture/bin/lipo" "$fixture/bin/ditto"

PATH="$fixture/bin:$PATH" PLUTIL="$fixture/bin/plutil" CODESIGN="$fixture/bin/codesign" LIPO="$fixture/bin/lipo" DITTO="$fixture/bin/ditto" \
  "$script" "$app" macos-v1.2.3 "$fixture/out"
[[ -f "$fixture/out/BOOHTACORD-macos-v1.2.3.zip" ]]
[[ -f "$fixture/out/BOOHTACORD-macos-v1.2.3.zip.sha256" ]]

resealed_marker="$fixture/resealed"
MOCK_RESEALED_MARKER="$resealed_marker" MOCK_VERIFY_FAIL_UNTIL_RESEALED=1 \
  PATH="$fixture/bin:$PATH" PLUTIL="$fixture/bin/plutil" CODESIGN="$fixture/bin/codesign" LIPO="$fixture/bin/lipo" DITTO="$fixture/bin/ditto" \
  "$script" "$app" macos-v1.2.3 "$fixture/resealed-out"
[[ -f "$resealed_marker" ]]

developer_id_marker="$fixture/developer-id-resealed"
if MOCK_RESEALED_MARKER="$developer_id_marker" MOCK_VERIFY_ALWAYS_FAIL=1 MOCK_SIGNATURE='Developer ID Application: Example' \
  PATH="$fixture/bin:$PATH" PLUTIL="$fixture/bin/plutil" CODESIGN="$fixture/bin/codesign" LIPO="$fixture/bin/lipo" DITTO="$fixture/bin/ditto" \
  "$script" "$app" macos-v1.2.3 "$fixture/invalid-developer-id"; then
  echo 'package script accepted a failed Developer ID signature' >&2
  exit 1
fi
[[ ! -e "$developer_id_marker" ]]

if PATH="$fixture/bin:$PATH" PLUTIL="$fixture/bin/plutil" CODESIGN="$fixture/bin/codesign" LIPO="$fixture/bin/lipo" DITTO="$fixture/bin/ditto" \
  "$script" "$app" macos-v9.9.9 "$fixture/bad"; then
  echo 'package script accepted a tag that does not match the app version' >&2
  exit 1
fi

echo 'macOS release package tests passed'
