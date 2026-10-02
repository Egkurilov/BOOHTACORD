#!/usr/bin/env bash
set -euo pipefail

bash tools/release/ssh/configure-deploy-ssh.sh
bash tools/ops/docker_storage/inspect_docker_storage.sh
