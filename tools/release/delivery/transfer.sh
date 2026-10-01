#!/usr/bin/env bash
set -euo pipefail
revision="${RELEASE_REVISION:?}"
[[ "$revision" =~ ^[0-9a-f]{40}$ ]]
[[ "$(git rev-parse HEAD)" == "$revision" ]]
bundle="${BUNDLE_DIRECTORY:?}/$revision.release.tar.gz"
[[ -f "$bundle" && -f "$bundle.sha256" ]]
expected="$(awk 'NR == 1 {print $1}' "$bundle.sha256")"
[[ "$expected" =~ ^[0-9a-f]{64}$ ]]
printf '%s  %s\n' "$expected" "$bundle" | sha256sum -c -
driver="${RUNNER_TEMP:?}/$revision.installer.tar.gz"
git archive --format=tar.gz --output="$driver" HEAD -- tools/release/archive tools/release/bundle tools/release/install tools/verify/oci/verify_oci.py
driver_sha="$(sha256sum "$driver" | awk '{print $1}')"
remote="${SSH_USER:?}@${DEPLOY_SERVER_IP:?}"
options=(-i "$HOME/.ssh/id_deploy" -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$HOME/.ssh/known_hosts")
current="$(ssh "${options[@]}" "$remote" sudo -n bash -s < tools/release/delivery/current_revision.sh)"
[[ "$current" =~ ^[0-9a-f]{40}$ ]]
git merge-base --is-ancestor "$current" "$revision" || { echo 'Installation cannot reverse deployed source history; use compatible rollback' >&2; exit 1; }
scp "${options[@]}" "$bundle" "$remote:/tmp/voice-platform-$revision.release.tar.gz"
scp "${options[@]}" "$driver" "$remote:/tmp/voice-platform-$revision.installer.tar.gz"
ssh "${options[@]}" "$remote" sudo -n bash -s -- "$revision" "$expected" "$driver_sha" "$current" < tools/release/delivery/install_received.sh
