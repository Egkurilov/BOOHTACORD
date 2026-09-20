package acquirevoiceleasepostgres

const selectActiveSession = `
SELECT token_digest FROM sessions
WHERE token_digest = $1 AND user_id = $2 AND revoked_at IS NULL`
const selectVoiceChannel = `
SELECT id::text FROM channels
WHERE id = $1 AND kind = 'VOICE' AND archived_at IS NULL AND admission_closed_at IS NULL`
const selectActiveLease = `
SELECT id::text, channel_id::text FROM voice_leases
WHERE user_id = $1 AND revoked_at IS NULL`
const revokeTransferredLease = `
WITH revoked AS (
    UPDATE voice_leases SET revoked_at = now(), revocation_reason = 'TRANSFER'
    WHERE id = $1 AND user_id = $2 AND revoked_at IS NULL
    RETURNING id, channel_id
), queued AS (
    INSERT INTO voice_sfu_revocations (lease_id, channel_id)
    SELECT id, channel_id FROM revoked
    ON CONFLICT (lease_id) DO NOTHING
), audited AS (
    INSERT INTO audit_events (actor_user_id, event_type, metadata)
    SELECT $2, 'VOICE_LEASE_TRANSFERRED', jsonb_build_object('prior_lease_id', id::text, 'prior_channel_id', channel_id::text)
    FROM revoked
)
SELECT id FROM revoked`
const insertVoiceLease = `
WITH issued AS (
    INSERT INTO voice_leases (id, user_id, channel_id, session_token_digest)
    VALUES ($1, $2, $3, $4)
    RETURNING id, channel_id
), audited AS (
    INSERT INTO audit_events (actor_user_id, event_type, metadata)
    SELECT $2, 'VOICE_LEASE_ISSUED', jsonb_build_object('lease_id', id::text, 'channel_id', channel_id::text)
    FROM issued
)
SELECT id::text, channel_id::text FROM issued`
