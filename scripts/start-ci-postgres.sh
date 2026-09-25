#!/usr/bin/env bash
set -euo pipefail

# GitVerse cloud jobs have no Docker socket. Start PostgreSQL inside the job.
as_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    sudo "$@"
  fi
}

if ! command -v pg_lsclusters >/dev/null 2>&1; then
  as_root apt-get update -qq
  as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq postgresql
fi

cluster="$(pg_lsclusters -h | awk 'NR == 1 { print $1 " " $2 }')"
if [[ -z "$cluster" ]]; then
  echo 'PostgreSQL installation did not create a cluster' >&2
  exit 1
fi
read -r version name <<< "$cluster"
if ! pg_isready -q -h 127.0.0.1 -p 5432; then
  as_root pg_ctlcluster "$version" "$name" start
fi

if (( EUID == 0 )); then
  postgres_psql=(runuser -u postgres -- psql)
else
  postgres_psql=(sudo -u postgres psql)
fi
if [[ "$("${postgres_psql[@]}" -Atqc \
  "SELECT 1 FROM pg_roles WHERE rolname = 'voice_platform_test'")" != 1 ]]; then
  "${postgres_psql[@]}" -v ON_ERROR_STOP=1 -c \
    "CREATE USER voice_platform_test WITH PASSWORD 'test-only-password'"
fi
if [[ "$("${postgres_psql[@]}" -Atqc \
  "SELECT 1 FROM pg_database WHERE datname = 'voice_platform_test'")" != 1 ]]; then
  "${postgres_psql[@]}" -v ON_ERROR_STOP=1 -c \
    'CREATE DATABASE voice_platform_test OWNER voice_platform_test'
fi

PGPASSWORD=test-only-password psql -h 127.0.0.1 -U voice_platform_test \
  -d voice_platform_test -v ON_ERROR_STOP=1 -Atqc 'SELECT 1' | grep -qx 1
