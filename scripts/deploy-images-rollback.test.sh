#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_root="$(mktemp -d)"
temporary_parent="$(cd "$(dirname "$temporary_root")" && pwd -P)"
temporary_root="$(cd "$temporary_root" && pwd -P)"
cleanup() {
  [[ "$temporary_root" == "$temporary_parent"/tmp.* && -d "$temporary_root" ]] || return 1
  rm -rf -- "$temporary_root"
}
trap cleanup EXIT
project_dir="$temporary_root/project"
bin_dir="$temporary_root/bin"
state_dir="$temporary_root/state"
mkdir -p "$project_dir" "$bin_dir" "$state_dir/postgres" "$state_dir/attachments"
printf 'services: {}\n' > "$project_dir/compose.yaml"
old_api="ghcr.io/example/api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
old_web="ghcr.io/example/web@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
new_api="ghcr.io/example/api@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
new_web="ghcr.io/example/web@sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
printf 'PUBLIC_HOST=example.test\nAPI_IMAGE=%s\nWEB_IMAGE=%s\n' "$old_api" "$old_web" > "$project_dir/.env"
printf '%s\n' "$old_api" > "$state_dir/running-api"
printf '%s\n' "$old_web" > "$state_dir/running-web"
printf 'postgres-volume-id\n' > "$state_dir/postgres/volume-id"
printf 'synthetic row 1\n' > "$state_dir/postgres/content"
printf 'attachments-volume-id\n' > "$state_dir/attachments/volume-id"
printf 'synthetic attachment\n' > "$state_dir/attachments/content"
before="$(sha256sum "$state_dir/postgres/"* "$state_dir/attachments/"*)"

cp "$root/scripts/qa12_rollback/fake_docker.sh" "$bin_dir/docker"
chmod 0755 "$bin_dir/docker"
cat > "$bin_dir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'curl %s\n' "$*" >> "$QA12_LOG"
[[ "$*" == *'https://example.test/api/v1/health'* ]]
[[ "$(cat "$QA12_STATE/maintenance")" == on ]]
[[ "$(cat "$QA12_STATE/running-api")" == "$(sed -n 's/^API_IMAGE=//p' "$QA12_PROJECT/.env")" ]]
EOF
cat > "$bin_dir/sleep" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sleep %s\n' "$*" >> "$QA12_LOG"
EOF
chmod 0755 "$bin_dir/curl" "$bin_dir/sleep"
export QA12_STATE="$state_dir" QA12_PROJECT="$project_dir" QA12_LOG="$temporary_root/commands.log"
export PATH="$bin_dir:$PATH" VOICE_PLATFORM_DIR="$project_dir"

export API_IMAGE="$new_api" WEB_IMAGE="$new_web" QA12_FAIL_PROXY_ONCE=1
if bash "$root/scripts/deploy-images.sh" > "$temporary_root/failed.out" 2>&1; then
  echo 'expected proxy rollout failure' >&2
  exit 1
fi
[[ "$(cat "$state_dir/running-api")" == "$new_api" ]]
[[ "$(cat "$state_dir/running-web")" == "$new_web" ]]
[[ -e "$state_dir/proxy-failed" ]]
[[ "$(cat "$state_dir/maintenance")" == off ]]
grep -Fxq "API_IMAGE=$new_api" "$project_dir/.env"
grep -Fq 'up -d --no-deps --no-build api web' "$QA12_LOG"
grep -Fq 'up -d --no-deps --no-build --force-recreate proxy' "$QA12_LOG"
! grep -q '^curl ' "$QA12_LOG"

export API_IMAGE="$old_api" WEB_IMAGE="$old_web" QA12_FAIL_PROXY_ONCE=0
bash "$root/scripts/deploy-images.sh" > "$temporary_root/rollback.out" 2>&1
[[ "$(cat "$state_dir/running-api")" == "$old_api" ]]
[[ "$(cat "$state_dir/running-web")" == "$old_web" ]]
[[ "$(cat "$state_dir/maintenance")" == off ]]
grep -Fxq "API_IMAGE=$old_api" "$project_dir/.env"
grep -Fxq "WEB_IMAGE=$old_web" "$project_dir/.env"
[[ "$(sha256sum "$state_dir/postgres/"* "$state_dir/attachments/"*)" == "$before" ]]
[[ "$(grep -c 'maintenance-admission --enable' "$QA12_LOG")" == 2 ]]
[[ "$(grep -c 'maintenance-admission --disable' "$QA12_LOG")" == 2 ]]
[[ "$(grep -c '^curl ' "$QA12_LOG")" == 1 ]]
! grep -Eq '(^| )down( |$)|(^| )volume (rm|prune)( |$)' "$QA12_LOG"
echo 'deploy-images rollback fake-Docker test passed'
