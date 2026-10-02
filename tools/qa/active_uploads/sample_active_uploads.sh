#!/usr/bin/env bash
set -euo pipefail
fail() { printf 'QA-08 active-upload sample failed: %s\n' "$1" >&2; exit 1; }
[[ ${1:-} =~ ^[0-9a-f]{40}$ ]] || fail 'expected deployed revision is invalid'
[[ ${DEPLOY_SERVER_IP:-} =~ ^[0-9A-Fa-f:.]+$ && ${SSH_USER:-} =~ ^[a-z_][a-z0-9_-]*$ ]] || fail 'SSH target is invalid'
count="${QA08_SAMPLE_COUNT:-90}"
[[ "$count" =~ ^[0-9]+$ ]] || fail 'sample count is invalid'
count=$((10#$count))
(( count >= 2 && count <= 120 )) || fail 'sample count is out of bounds'
[[ -r tools/ops/attachment_audit/audit-attachment-volume.sh ]] || fail 'audit script is unavailable'

field() {
  awk -F= -v key="$1" '$1 == key { hits++; value = $2 } END {
    if (hits != 1 || value !~ /^[0-9]+$/) exit 1
    print value
  }' <<< "$2"
}

remote="${SSH_USER}@${DEPLOY_SERVER_IP}"
ssh_options=(-i "$HOME/.ssh/id_deploy" -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$HOME/.ssh/known_hosts")
active=0
released=0
peak=0
minimum=-1
for ((index = 1; index <= count; index++)); do
  snapshot="$(ssh "${ssh_options[@]}" "$remote" bash -s -- "$1" < tools/ops/attachment_audit/audit-attachment-volume.sh)" || fail "audit unavailable at sample $index"
  available="$(field available_bytes "$snapshot")" || fail "available bytes invalid at sample $index"
  required="$(field required_bytes "$snapshot")" || fail "required bytes invalid at sample $index"
  reserved="$(field reserved_bytes "$snapshot")" || fail "reserved bytes invalid at sample $index"
  available=$((10#$available)); required=$((10#$required)); reserved=$((10#$reserved))
  (( available >= required )) || fail "headroom below guarded threshold at sample $index"
  (( minimum < 0 || available < minimum )) && minimum=$available
  if (( reserved > 0 )); then
    active=$((active + 1))
    (( reserved > peak )) && peak=$reserved
  elif (( active > 0 )); then
    released=1
  fi
  printf 'sample_utc=%s sample=%d available_bytes=%d required_bytes=%d reserved_bytes=%d\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$index" "$available" "$required" "$reserved"
  if (( index < count )); then sleep 1; fi
done
printf 'samples=%d active_samples=%d peak_reserved_bytes=%d minimum_available_bytes=%d reservation_released=%d\n' \
  "$count" "$active" "$peak" "$minimum" "$released"
(( active >= 2 && peak >= 25000000 && released == 1 )) || fail 'active reservation and release were not both observed'
