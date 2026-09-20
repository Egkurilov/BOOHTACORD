# Administrator bootstrap and recovery

Run migrations before any recovery command. No command accepts a password as a command-line flag. Run these one-shot commands from the server owner's terminal; pass the password via standard input so process arguments, application logs and Compose files contain no secret.

Bootstrap the first administrator before opening registration:

```bash
read -rsp 'Initial administrator password: ' BOOTSTRAP_PASSWORD; echo
printf '%s\n' "$BOOTSTRAP_PASSWORD" | sudo docker compose --project-directory /opt/voice-platform -f /opt/voice-platform/compose.yaml --profile operator run --rm -T bootstrap-admin --login owner --password-stdin
unset BOOTSTRAP_PASSWORD
```

The first successful bootstrap creates an `ADMINISTRATOR` and an audit event. Any later bootstrap exits successfully with “already initialized” and changes neither role nor password.

If the command reports that bootstrap state is incomplete, do not retry it, use administrator recovery, or create an account directly in PostgreSQL. Deploy the current repair migration first; it links only the singleton state that has no administrator to exactly one existing active administrator and records the missing initial-bootstrap audit event. A state that does not meet those exact conditions remains unchanged for owner investigation.

Emergency recovery is only available when no active administrator exists. It restores an existing account as an unblocked `ADMINISTRATOR`, replaces its password, revokes its prior sessions, and writes an `ADMINISTRATOR_RECOVERED` audit event:

```bash
read -rsp 'Replacement administrator password: ' RECOVERY_PASSWORD; echo
printf '%s\n' "$RECOVERY_PASSWORD" | sudo docker compose --project-directory /opt/voice-platform -f /opt/voice-platform/compose.yaml --profile operator run --rm -T recover-admin --login owner --password-stdin
unset RECOVERY_PASSWORD
```

If the sole active administrator has lost its password, use the separate, explicitly acknowledged command below. It operates only when `owner` is the one active, unblocked `ADMINISTRATOR`; it does not promote another account or change a role. It replaces the password, revokes the account's active sessions and voice leases, and records a `LAST_ADMINISTRATOR_ACCESS_RECOVERED` audit event:

```bash
read -rsp 'Replacement administrator password: ' RECOVERY_PASSWORD; echo
printf '%s\n' "$RECOVERY_PASSWORD" | sudo docker compose --project-directory /opt/voice-platform -f /opt/voice-platform/compose.yaml --profile operator run --rm -T recover-last-admin-access --login owner --password-stdin --confirm-sole-active-administrator-access-recovery
unset RECOVERY_PASSWORD
```

The server owner must transfer the password through a controlled channel. These owner-operated commands do not provide backup, account discovery, or a normal administration workflow.

## Continuous delivery inputs

The GitHub Actions release path runs only after checks pass on a trusted `push` to `main`; it publishes GHCR images and deploys their digest references, never `latest`. Configure these repository secrets before its first run: `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_PRIVATE_KEY`, and `DEPLOY_KNOWN_HOSTS`. The known-hosts secret must contain the server's verified SSH host key; the workflow never uses `ssh-keyscan` or accepts a changed key.

The deployment server must already be able to pull the private GHCR package, if the package is not public. The workflow copies only the Compose file, Caddyfile and release script, then runs migrations before restarting API/web/proxy. It does not run for pull requests, delete volumes or run down migrations.

No Git remote or configured repository secrets are currently available in this workspace, so a successful GHCR publish and automatic deployment remain unverified until the owner connects the repository and provides these inputs.

## Maintenance admission during a trusted release

The release script enables maintenance admission, waits 15 seconds for the public warning to reach browsers, pulls immutable images, runs migrations, restarts API/web/proxy, validates Caddy and checks public health. It disables admission only after that health check succeeds. A failed release intentionally leaves admission active; investigate and recover the deployment before disabling it.

The very first release that introduces this capability needs a one-time schema preparation because its admission row does not exist yet. Confirm that the candidate migration is the only pending compatible migration, run it as the separate checked migration step, and then run the normal release script. Do not claim that this one-time preparation was maintenance-protected; every later release uses the normal enable-before-pull sequence.

For a controlled verification, use a second browser as an observer. During the warning, confirm that a new registration, login and new voice lease receive a maintenance refusal, while an existing session can still read protected data and an existing media connection is not deliberately disconnected before the restart. After health succeeds and admission is disabled, refresh both browsers and confirm the banner is gone and new admission resumes. Record only image digests, UTC times and pass/fail outcomes—never cookies, passwords, media credentials, private keys or host fingerprints.

## Stale staging cleanup

The following explicit, owner-operated command removes only direct, regular `staging/upload-*.part` files strictly older than one hour:

```bash
sudo docker compose --project-directory /opt/voice-platform -f /opt/voice-platform/compose.yaml --profile operator run --rm cleanup-stale-staging
```

It preserves symlinks, directories, unexpected names, data exactly at the one-hour cutoff, published attachments, unattached objects, and all database rows. It is deliberately not scheduled and must be run only after the owner decides that deletion is appropriate. Its output reports only the aggregate count; it does not reveal attachment names or contents.
