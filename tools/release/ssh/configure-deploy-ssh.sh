#!/usr/bin/env bash
set -euo pipefail
[[ "$DEPLOY_SERVER_IP" =~ ^[0-9A-Fa-f:.]+$ ]]
[[ "$SSH_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]
[[ -n "$DEPLOY_SSH_PRIVATE_KEY" ]]
install -d -m 700 ~/.ssh
umask 077
printf '%s\n' "$DEPLOY_SSH_PRIVATE_KEY" > ~/.ssh/id_deploy
chmod 600 ~/.ssh/id_deploy
ssh-keygen -y -f ~/.ssh/id_deploy > /dev/null
printf '%s ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOTOd1clMcOJN4YNCn+EDZ6IAM7x99fHD8O8Zk3umZtr\n' "$DEPLOY_SERVER_IP" > ~/.ssh/known_hosts
chmod 600 ~/.ssh/known_hosts
