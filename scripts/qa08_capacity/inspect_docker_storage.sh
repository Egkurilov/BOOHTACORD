#!/usr/bin/env bash
set -euo pipefail

[[ -n "${DEPLOY_SERVER_IP:-}" && -n "${SSH_USER:-}" ]] || {
  printf 'QA-08 storage inspection: SSH target is unavailable\n' >&2
  exit 1
}

remote="${SSH_USER}@${DEPLOY_SERVER_IP}"
ssh_options=(-i "$HOME/.ssh/id_deploy" -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$HOME/.ssh/known_hosts")
ssh "${ssh_options[@]}" "$remote" 'sudo -n docker system df'
