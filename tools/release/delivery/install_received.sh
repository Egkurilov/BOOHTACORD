#!/usr/bin/env bash
set -euo pipefail
revision="$1"; bundle_sha="$2"; driver_sha="$3"; current="$4"
[[ "$revision" =~ ^[0-9a-f]{40}$ && "$bundle_sha" =~ ^[0-9a-f]{64}$ && "$driver_sha" =~ ^[0-9a-f]{64}$ ]]
[[ "$current" =~ ^[0-9a-f]{40}$ ]]
bundle="/tmp/voice-platform-$revision.release.tar.gz"
driver="/tmp/voice-platform-$revision.installer.tar.gz"
[[ -r /etc/voice-platform/release-signing.pub.pem ]]
printf '%s  %s\n' "$bundle_sha" "$bundle" "$driver_sha" "$driver" | sha256sum -c -
temporary="$(mktemp -d /opt/voice-platform-installer.XXXXXX)"
trap 'rm -rf "$temporary"' EXIT
tar -xzf "$driver" -C "$temporary" --no-same-owner
cd "$temporary"
python3 -m tools.release.install.run "$bundle" "$revision" "$bundle_sha" --expected-current-revision "$current" </dev/null
# Remove only these successfully installed transport copies; retained releases stay.
rm -f "$bundle" "$driver"
