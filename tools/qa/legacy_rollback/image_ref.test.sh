#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/image_ref.sh"
temporary_root="$(mktemp -d)"
temporary_parent="$(cd "$(dirname "$temporary_root")" && pwd -P)"
temporary_root="$(cd "$temporary_root" && pwd -P)"
cleanup() {
  [[ "$temporary_root" == "$temporary_parent"/tmp.* && -d "$temporary_root" ]] || return 1
  rm -rf -- "$temporary_root"
}
trap cleanup EXIT
revision="$(printf 'a%.0s' {1..40})"
mkdir -p "$temporary_root/$revision"
if qa12_image_ref "$temporary_root" "$revision" api >/dev/null 2>&1; then
  echo 'missing digest receipt was accepted' >&2
  exit 1
fi
digest="sha256:$(printf '1%.0s' {1..64})"
printf '{"index_digest":"%s"}\n' "$digest" > "$temporary_root/$revision/api.oci.json"
[[ "$(qa12_image_ref "$temporary_root" "$revision" api)" == "voice-platform-api@$digest" ]]
printf '{"index_digest":"sha256:invalid"}\n' > "$temporary_root/$revision/api.oci.json"
if qa12_image_ref "$temporary_root" "$revision" api >/dev/null 2>&1; then
  echo 'invalid digest receipt was accepted' >&2
  exit 1
fi
echo 'QA-12 digest-only image refs passed'
