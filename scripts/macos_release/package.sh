#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'macOS release package: %s\n' "$1" >&2
  exit 1
}

[[ $# -eq 3 ]] || fail 'usage: package.sh APP_BUNDLE RELEASE_TAG OUTPUT_DIR'
app="$1"
tag="$2"
output_dir="$3"
plutil="${PLUTIL:-/usr/bin/plutil}"
codesign="${CODESIGN:-/usr/bin/codesign}"
lipo="${LIPO:-/usr/bin/lipo}"
ditto="${DITTO:-/usr/bin/ditto}"
shasum="${SHASUM:-/usr/bin/shasum}"
stat="${STAT:-/usr/bin/stat}"
[[ -d "$app/Contents" && -f "$app/Contents/Info.plist" ]] || fail 'app bundle is incomplete'
[[ "$(basename "$app")" == 'BOOHTACORD.app' ]] || fail 'unexpected app bundle name'
[[ "$tag" =~ ^macos-v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'release tag must match macos-vX.Y.Z'

version="$("$plutil" -extract CFBundleShortVersionString raw -o - "$app/Contents/Info.plist")" || fail 'could not read app version'
[[ "$tag" == "macos-v$version" ]] || fail "release tag does not match app bundle version $version"
executable="$("$plutil" -extract CFBundleExecutable raw -o - "$app/Contents/Info.plist")" || fail 'could not read app executable name'
[[ -f "$app/Contents/MacOS/$executable" ]] || fail 'app executable is missing'
architectures="$("$lipo" -archs "$app/Contents/MacOS/$executable")" || fail 'could not inspect app architectures'
[[ " $architectures " == *' arm64 '* && " $architectures " == *' x86_64 '* ]] || fail "app is not universal (architectures: $architectures)"

"$codesign" --verify --deep --strict --verbose=2 "$app" || fail 'app signature verification failed'
mkdir -p "$output_dir"
archive_name="BOOHTACORD-$tag.zip"
archive="$output_dir/$archive_name"
checksum="$archive.sha256"
[[ ! -e "$archive" && ! -e "$checksum" ]] || fail 'release output already exists'

"$ditto" -c -k --sequesterRsrc --keepParent "$app" "$archive"
archive_size="$("$stat" -f '%z' "$archive")"
[[ "$archive_size" -le 95000000 ]] || fail "ZIP exceeds the 95 MB GitVerse asset safety ceiling ($archive_size bytes)"
(cd "$output_dir" && "$shasum" -a 256 "$archive_name") > "$checksum"
printf 'Prepared %s (%s bytes)\n' "$archive" "$archive_size"
