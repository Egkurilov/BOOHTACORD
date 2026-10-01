#!/usr/bin/env bash
set -euo pipefail

if command -v pwsh >/dev/null 2>&1; then
  exit 0
fi
source /etc/os-release
if [[ "$ID" != ubuntu ]]; then
  echo 'PowerShell CI installer requires Ubuntu' >&2
  exit 1
fi
if [[ "$(dpkg --print-architecture)" != amd64 ]]; then
  echo 'PowerShell CI package requires amd64' >&2
  exit 1
fi
as_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    sudo "$@"
  fi
}

as_root apt-get update -qq
as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq wget
package="$(mktemp --suffix=.deb)"
trap 'rm -f "$package"' EXIT
wget -q 'https://github.com/PowerShell/PowerShell/releases/download/v7.6.6/powershell_7.6.6-1.deb_amd64.deb' -O "$package"
echo '9585f38ab5a026c3fc0995486e26e12050777960fef47a22dca98b577c5d27a7  '"$package" | sha256sum -c -
as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$package"
pwsh -NoProfile -Command 'exit 0'
