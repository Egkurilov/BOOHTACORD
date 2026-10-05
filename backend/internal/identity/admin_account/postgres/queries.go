package adminpostgres

const updateAccount = `
WITH updated AS (
    UPDATE users
    SET role = $2,
        blocked_at = CASE WHEN $3 THEN COALESCE(blocked_at, now()) ELSE NULL END,
        updated_at = now()
    WHERE id = $1
      AND ($5::timestamptz IS NULL OR updated_at = $5::timestamptz)
      AND NOT (
          role = 'ADMINISTRATOR'
          AND blocked_at IS NULL
          AND ($2 <> 'ADMINISTRATOR' OR $3)
          AND NOT EXISTS (
              SELECT 1 FROM users
              WHERE role = 'ADMINISTRATOR'
                AND blocked_at IS NULL
                AND id <> $1
          )
      )
    RETURNING id, role, blocked_at IS NOT NULL AS blocked
), revoked AS (
    UPDATE sessions
    SET revoked_at = now()
    WHERE user_id IN (SELECT id FROM updated)
      AND $3
      AND revoked_at IS NULL
), revoked_leases AS (
    UPDATE voice_leases
    SET revoked_at = now(), revocation_reason = 'BANNED'
    WHERE user_id IN (SELECT id FROM updated)
      AND $3
      AND revoked_at IS NULL
    RETURNING id, channel_id
), queued AS (
    INSERT INTO voice_sfu_revocations (lease_id, channel_id)
    SELECT id, channel_id FROM revoked_leases
    ON CONFLICT (lease_id) DO NOTHING
), audited AS (
    INSERT INTO audit_events (actor_user_id, event_type, target_user_id)
    SELECT $4, 'ACCOUNT_ADMIN_STATE_UPDATED', id FROM updated
)
SELECT id::text, role, blocked FROM updated`
