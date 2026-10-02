#!/usr/bin/env bash
set -euo pipefail
[[ "${CURRENT_SHA:-}" =~ ^[0-9a-f]{40}$ && "${PREVIOUS_SHA:-}" =~ ^[0-9a-f]{40}$ ]]
[[ "$CURRENT_SHA" != "$PREVIOUS_SHA" ]]
[[ "${OBSERVERS_CONFIRMED:-}" == two-browsers-ready ]]
remote="${SSH_USER:?}@${DEPLOY_SERVER_IP:?}"
options=(-i "$HOME/.ssh/id_deploy" -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$HOME/.ssh/known_hosts")
ssh "${options[@]}" "$remote" sudo -n env "PYTHONPATH=/opt/voice-platform-releases/$CURRENT_SHA" \
  python3 -m tools.release.rollback.run "$CURRENT_SHA" "$PREVIOUS_SHA" --rehearse --observe-seconds 30
