#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'Attachment volume pre-build check failed: %s\n' "$1" >&2
  exit 1
}

# Match backend reserve_upload_space: max(2 GiB, ceil(filesystem bytes / 10)).
# Keep one additional protected-size buffer for image builds and 25 MB for an upload.
# Live in-flight reservations still require a BE-15 measurement after deployment.
mountpoint="$(docker volume inspect --format '{{.Mountpoint}}' voice-platform_attachments-data)" || fail 'attachment volume unavailable'
[[ "$mountpoint" == /* && -d "$mountpoint" ]] || fail 'attachment volume mountpoint unavailable'
sample="$(df -B1 --output=avail,size -- "$mountpoint")" || fail 'attachment filesystem measurement unavailable'
numbers="$(printf '%s\n' "$sample" | awk 'NR == 2 { print $1, $2 } END { if (NR != 2) exit 1 }')" || fail 'attachment filesystem measurement unavailable'
read -r available total <<< "$numbers"
[[ "$available" =~ ^[0-9]+$ && "$total" =~ ^[0-9]+$ ]] || fail 'invalid attachment filesystem measurement'
available=$((10#$available))
total=$((10#$total))
(( total > 0 && available <= total )) || fail 'invalid attachment filesystem measurement'

protected=$(((total + 9) / 10))
(( protected >= 2147483648 )) || protected=2147483648
required=$((protected * 2 + 25000000))
(( available >= required )) || fail "insufficient attachment volume headroom ($available < $required bytes)"
printf 'Attachment volume pre-build headroom: %s bytes available; %s bytes required.\n' "$available" "$required"
