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
[[ "$*" == "--verify --deep --strict --verbose=2 "* ]]
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
chmod +x "$fixture/bin/codesign" "$fixture/bin/plutil" "$fixture/bin/lipo" "$fixture/bin/ditto"

PATH="$fixture/bin:$PATH" PLUTIL="$fixture/bin/plutil" CODESIGN="$fixture/bin/codesign" LIPO="$fixture/bin/lipo" DITTO="$fixture/bin/ditto" \
  "$script" "$app" macos-v1.2.3 "$fixture/out"
[[ -f "$fixture/out/BOOHTACORD-macos-v1.2.3.zip" ]]
[[ -f "$fixture/out/BOOHTACORD-macos-v1.2.3.zip.sha256" ]]

if PATH="$fixture/bin:$PATH" PLUTIL="$fixture/bin/plutil" CODESIGN="$fixture/bin/codesign" LIPO="$fixture/bin/lipo" DITTO="$fixture/bin/ditto" \
  "$script" "$app" macos-v9.9.9 "$fixture/bad"; then
  echo 'package script accepted a tag that does not match the app version' >&2
  exit 1
fi

echo 'macOS release package tests passed'
