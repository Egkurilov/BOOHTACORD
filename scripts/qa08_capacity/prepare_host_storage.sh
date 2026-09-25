#!/usr/bin/env bash
set -euo pipefail

bash scripts/configure-deploy-ssh.sh
bash scripts/qa08_capacity/inspect_docker_storage.sh
