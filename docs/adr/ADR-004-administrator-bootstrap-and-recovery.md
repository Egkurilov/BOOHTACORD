# ADR-004: immutable bootstrap and audited administrator recovery

## Status

Accepted.

## Decision

The first administrator is created only by `cmd/bootstrap_admin`, never by public registration. A one-row `bootstrap_state` claim uses `INSERT … ON CONFLICT DO NOTHING` in the same SQL command as user creation and audit-event insertion. Exactly one concurrent caller can claim initialization; later callers receive `ErrAlreadyInitialized` and the command returns success without changing any existing account, role or password.

`cmd/recover_admin` is an owner-operated emergency command for a deployment with no active administrator. It reads a replacement password only from standard input, normalizes the existing login, and runs under a transaction-level PostgreSQL advisory lock. After obtaining the lock, it uses a fresh read-committed statement snapshot to refuse recovery if an active administrator exists. Otherwise it atomically promotes and unblocks the selected existing account, replaces its Argon2id hash, revokes its sessions, and emits an `ADMINISTRATOR_RECOVERED` audit event.

`cmd/recover_last_admin_access` is a distinct owner-operated command for a lost password of the sole active administrator. It requires the explicit `--confirm-sole-active-administrator-access-recovery` acknowledgement and updates only an existing, unblocked `ADMINISTRATOR` when it is exactly the one active administrator. It cannot promote a member or act when there are zero or multiple active administrators. The same transaction-level lock protects the recovery family; the command replaces the Argon2id hash, revokes sessions and voice leases, and emits `LAST_ADMINISTRATOR_ACCESS_RECOVERED`. Command output, audit metadata and SQL contain no raw password or reset/session token.

## Consequences

- The bootstrap sentinel remains set even if all administrators are later blocked or demoted; recovery, rather than bootstrap rerun, is the explicit owner action.
- The zero-active-administrator recovery is intentionally unavailable while a normal active administrator exists, preventing it from becoming a routine privilege-escalation path.
- Sole-administrator access recovery is limited to the current sole active administrator and requires an explicit owner acknowledgement, so it cannot be used to promote another account or bypass normal multi-administrator password-reset controls.
- `audit_events` records only actor/target IDs, event type and non-secret metadata. It must never receive DM text, message content, passwords, reset URLs, session tokens or attachment data.
- Real PostgreSQL concurrency and command-flow evidence remain required before this capability is considered complete.
