#!/usr/bin/env bash
set -euo pipefail

bash scripts/configure-deploy-ssh.sh
bash scripts/qa08_capacity/inspect_docker_storage.sh

remote="${SSH_USER}@${DEPLOY_SERVER_IP}"
ssh_options=(-i "$HOME/.ssh/id_deploy" -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$HOME/.ssh/known_hosts")
ssh "${ssh_options[@]}" "$remote" sudo -n bash -s < scripts/qa08_capacity/prune_build_cache.sh
