#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'Attachment capacity audit failed: %s\n' "$1" >&2; exit 1; }
if [[ ${1:-} =~ ^[0-9a-f]{40}$ ]]; then
  expected_image="voice-platform-api:$1"
  receipt="${VOICE_PLATFORM_RELEASE_ROOT:-/opt/voice-platform-releases}/$1/api.oci.json"
  if sudo -n test -r "$receipt"; then
    digest="$(sudo -n python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["index_digest"])' "$receipt")" || fail 'OCI receipt unavailable'
    [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || fail 'OCI receipt digest invalid'
    expected_image="voice-platform-api@$digest"
  fi
elif [[ ${1:-} =~ ^voice-platform-api@sha256:[0-9a-f]{64}$ ]]; then
  expected_image="$1"
elif [[ ${1:-} =~ ^ghcr[.]io/[a-z0-9][a-z0-9-]*/voice-platform-api@sha256:[0-9a-f]{64}$ ]]; then
  expected_image="$1"
else
  fail 'expected deployed API revision or GHCR digest is invalid'
fi

mountpoint="$(sudo -n docker volume inspect --format '{{.Mountpoint}}' voice-platform_attachments-data)" || fail 'volume inspect unavailable'
[[ "$mountpoint" == /* ]] || fail 'volume mountpoint unavailable'
sudo -n test -d "$mountpoint" || fail 'volume mountpoint missing'
sample="$(sudo -n df -B1 --output=avail,size -- "$mountpoint")" || fail 'filesystem measurement unavailable'
numbers="$(printf '%s\n' "$sample" | awk 'NR == 2 { print $1, $2 } END { if (NR != 2) exit 1 }')" || fail 'filesystem measurement invalid'
read -r available total <<< "$numbers"
[[ "$available" =~ ^[0-9]+$ && "$total" =~ ^[0-9]+$ ]] || fail 'filesystem measurement invalid'
available=$((10#$available)); total=$((10#$total))
(( total > 0 && available <= total )) || fail 'filesystem measurement invalid'
filesystem="$(sudo -n findmnt -T "$mountpoint" -n -o SOURCE,FSTYPE,TARGET)" || fail 'filesystem identity unavailable'
read -r source fs_type target extra <<< "$filesystem"
[[ -n "$source" && -n "$fs_type" && "$target" == /* && -z "${extra:-}" ]] || fail 'filesystem identity invalid'

container="$(sudo -n docker ps --filter label=com.docker.compose.project=voice-platform --filter label=com.docker.compose.service=api --format '{{.ID}}')" || fail 'API container lookup unavailable'
[[ "$container" =~ ^[0-9a-f]{12,64}$ ]] || fail 'expected exactly one running API container'
api_image="$(sudo -n docker inspect --format '{{.Config.Image}}' "$container")" || fail 'API image unavailable'
[[ "$api_image" == "$expected_image" ]] || fail 'running API image differs from requested revision'
private_ip="$(sudo -n docker inspect --format '{{with index .NetworkSettings.Networks "voice-platform_private"}}{{.IPAddress}}{{end}}' "$container")" || fail 'API private address unavailable'
[[ "$private_ip" =~ ^[0-9]+([.][0-9]+){3}$ ]] || fail 'API private address invalid'
health="$(curl -fsS --max-time 5 "http://${private_ip}:8080/api/v1/health")" || fail 'API health unavailable'
[[ "$health" =~ \"status\"[[:space:]]*:[[:space:]]*\"ok\" ]] || fail 'API health is not ok'
metrics="$(curl -fsS --max-time 5 "http://${private_ip}:8080/metrics")" || fail 'private API metrics unavailable'

metric() {
  printf '%s\n' "$metrics" | awk -v key="$1" '
    $1 == key {
      count++
      if ($2 !~ /^[0-9]+([.][0-9]+)?([eE][+-]?[0-9]+)?$/ || NF != 2) bad = 1
      value = $2
    }
    END { if (count != 1 || bad) exit 1; printf "%.0f", value }
  '
}
metric_available="$(metric voice_platform_attachment_filesystem_available_bytes)" || fail 'available-byte metric invalid'
metric_total="$(metric voice_platform_attachment_filesystem_total_bytes)" || fail 'total-byte metric invalid'
snapshot_success="$(metric voice_platform_attachment_filesystem_snapshot_success)" || fail 'snapshot metric invalid'
reserved="$(metric voice_platform_attachment_upload_reserved_bytes)" || fail 'in-flight reservation metric invalid'
[[ "$metric_available" =~ ^[0-9]+$ && "$metric_total" =~ ^[0-9]+$ && "$reserved" =~ ^[0-9]+$ ]] || fail 'metrics invalid'
[[ "$snapshot_success" == 1 && "$metric_total" == "$total" ]] || fail 'API filesystem snapshot differs from host'
(( metric_available <= total )) || fail 'API filesystem snapshot invalid'

protected=$(((total + 9) / 10))
(( protected >= 2147483648 )) || protected=2147483648
required=$((protected * 2 + 25000000 + reserved))
(( available >= required && metric_available >= required )) || fail "insufficient current headroom ($available host bytes; $metric_available API bytes; $required required bytes)"

printf 'volume=voice-platform_attachments-data\nfilesystem_source=%s\nfilesystem_type=%s\nfilesystem_target=%s\n' "$source" "$fs_type" "$target"
printf 'available_bytes=%s\ntotal_bytes=%s\nrequired_bytes=%s\nreserved_bytes=%s\nmetric_available_bytes=%s\n' "$available" "$total" "$required" "$reserved" "$metric_available"
printf 'snapshot_success=1\napi_image=%s\napi_health=ok\n' "$api_image"
