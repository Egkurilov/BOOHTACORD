#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d /tmp/qa05_retry.XXXXXXXX)
database="qa05_retry_${$}"
storage="$work/storage"
api_pid=''
proxy_pid=''
mounted=0
created=0

cleanup() {
  trap - EXIT INT TERM
  [[ -z "$proxy_pid" ]] || { kill "$proxy_pid" 2>/dev/null || true; wait "$proxy_pid" 2>/dev/null || true; }
  if [[ -n "$api_pid" ]]; then
    child=$(pgrep -P "$api_pid" || true)
    [[ -z "$child" ]] || kill $child 2>/dev/null || true
    kill "$api_pid" 2>/dev/null || true
    wait "$api_pid" 2>/dev/null || true
  fi
  if [[ $created == 1 ]]; then runuser -u postgres -- dropdb --if-exists --force "$database"; fi
  if [[ $mounted == 1 ]]; then umount "$storage"; fi
  if [[ -f /tmp/qa05_retry_active_path ]] && [[ $(cat /tmp/qa05_retry_active_path) == "$work" ]]; then
    rm -- /tmp/qa05_retry_active_path
  fi
  case "$work" in /tmp/qa05_retry.*) rm -rf -- "$work" ;; *) echo 'unsafe cleanup path' >&2; exit 1 ;; esac
}
trap cleanup EXIT INT TERM

chmod 711 "$work"
mkdir "$storage"
mount -t tmpfs -o size=3G,mode=0700,uid=$(id -u postgres),gid=$(id -g postgres) tmpfs "$storage"
mounted=1
runuser -u postgres -- mkdir -p "$storage/staging" "$storage/unattached"
runuser -u postgres -- createdb "$database"
created=1
printf '%s\n' "$database" > "$work/database"
database_url="postgres://postgres@/$database?host=/var/run/postgresql"
cd "$repo/backend"
go build -o "$work/migrate" ./cmd/migrate
go build -o "$work/bootstrap" ./cmd/bootstrap_admin
go build -o "$work/api" ./cmd/api
runuser -u postgres -- env DATABASE_URL="$database_url" "$work/migrate"
openssl rand -base64 36 > "$work/password"
chmod 600 "$work/password"
runuser -u postgres -- env DATABASE_URL="$database_url" "$work/bootstrap" --login qa05admin --password-stdin < "$work/password"

runuser -u postgres -- env DATABASE_URL="$database_url" API_ADDR=127.0.0.1:18096 \
  PUBLIC_ORIGIN=http://localhost:18796 ATTACHMENTS_DIRECTORY="$storage" \
  LIVEKIT_PUBLIC_WS_URL=ws://127.0.0.1:17880 LIVEKIT_PRIVATE_HTTP_URL=http://127.0.0.1:17880 \
  LIVEKIT_API_KEY=qa05-local LIVEKIT_API_SECRET=qa05-local-only-secret-12345 \
  "$work/api" > "$work/api.log" 2>&1 &
api_pid=$!
for _ in {1..50}; do
  if curl -sf http://127.0.0.1:18096/api/v1/health >/dev/null; then break; fi
  sleep 0.2
done
curl -sf http://127.0.0.1:18096/api/v1/health >/dev/null

python3 "$repo/scripts/qa05_browser_real507/proxy.py" "$repo/clients/web/dist" 18096 18796 &
proxy_pid=$!
for _ in {1..50}; do
  if curl -sf http://127.0.0.1:18796/api/v1/health >/dev/null; then break; fi
  sleep 0.2
done
curl -sf http://127.0.0.1:18796/api/v1/health >/dev/null
printf 'qa05_origin=http://localhost:18796\nqa05_work=%s\nqa05_database=%s\nqa05_storage=%s\n' "$work" "$database" "$storage"
printf '%s\n' "$work" > /tmp/qa05_retry_active_path
wait "$proxy_pid"
