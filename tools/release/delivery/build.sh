#!/usr/bin/env bash
set -euo pipefail
[[ "${GITHUB_REF:-}" == refs/heads/master ]]
[[ "${GITHUB_SHA:-}" =~ ^[0-9a-f]{40}$ ]]
[[ "$(git rev-parse HEAD)" == "$GITHUB_SHA" ]]
[[ -n "${RELEASE_SIGNING_PRIVATE_KEY:-}" ]]
umask 077
key="$(mktemp "${RUNNER_TEMP:?}/release-signing.XXXXXX")"
trap 'rm -f "$key"' EXIT
printf '%s\n' "$RELEASE_SIGNING_PRIVATE_KEY" > "$key"
unset RELEASE_SIGNING_PRIVATE_KEY
python3 -m tools.build.server.run --checks .out/checks --signing-key "$key"
