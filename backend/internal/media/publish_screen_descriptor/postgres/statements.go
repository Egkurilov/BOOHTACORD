package publishscreendescriptorpostgres

const lockLease = `
SELECT lease.user_id::text, lease.channel_id::text,
       lease.screen_profile_operation_revision, lease.screen_profile_operation_hash
FROM voice_leases AS lease
JOIN sessions AS session ON session.token_digest = lease.session_token_digest AND session.user_id = lease.user_id
JOIN channels AS channel ON channel.id = lease.channel_id
JOIN users AS account ON account.id = lease.user_id
WHERE lease.id = $1 AND lease.user_id = $2 AND lease.session_token_digest = $3
  AND lease.revoked_at IS NULL AND session.revoked_at IS NULL
  AND channel.kind = 'VOICE' AND channel.archived_at IS NULL AND channel.admission_closed_at IS NULL
  AND account.blocked_at IS NULL
FOR UPDATE OF lease`

const saveReceipt = `
UPDATE voice_leases
SET screen_profile_operation_revision = $1, screen_profile_operation_hash = $2
WHERE id = $3 AND revoked_at IS NULL`
