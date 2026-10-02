#!/usr/bin/env bash
set -euo pipefail

[[ -n "${DEPLOY_SERVER_IP:-}" && -n "${SSH_USER:-}" ]] || {
  printf 'QA-08 storage inspection: SSH target is unavailable\n' >&2
  exit 1
}

remote="${SSH_USER}@${DEPLOY_SERVER_IP}"
ssh_options=(-i "$HOME/.ssh/id_deploy" -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$HOME/.ssh/known_hosts")
ssh "${ssh_options[@]}" "$remote" 'sudo -n docker system df'
printf 'Voice Platform image tags and dangling images:\n'
ssh "${ssh_options[@]}" "$remote" \
  'sudo -n docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}"' \
  | awk '$1 ~ /^voice-platform-(api|web):/ || $1 == "<none>:<none>"'
printf 'Running Voice Platform container images:\n'
ssh "${ssh_options[@]}" "$remote" \
  'sudo -n docker ps --format "{{.Names}} {{.Image}}"' \
  | awk '$2 ~ /^voice-platform-(api|web):/'
printf 'Unique image usage for release and build families:\n'
ssh "${ssh_options[@]}" "$remote" 'sudo -n docker system df -v' \
  | awk '/^REPOSITORY[[:space:]]+TAG/ || $1 ~ /^(voice-platform-|golang|node|postgres|alpine|debian|ubuntu|caddy|nginx|livekit)/ || $1 == "<none>"'
