WITH revoked AS (
    UPDATE sessions SET revoked_at=now()
    WHERE user_id=$1::uuid AND revoked_at IS NULL
      AND (($4::boolean AND token_digest<>$2::bytea) OR
           (NOT $4::boolean AND public_id=$3::uuid))
    RETURNING token_digest
), leases AS (
    UPDATE voice_leases SET revoked_at=now(),revocation_reason='SESSION_REVOKED'
    WHERE session_token_digest IN (SELECT token_digest FROM revoked) AND revoked_at IS NULL
    RETURNING id,channel_id
), pending AS (
    INSERT INTO voice_sfu_revocations(lease_id,channel_id)
    SELECT id,channel_id FROM leases ON CONFLICT(lease_id) DO NOTHING
)
SELECT count(*)::int,coalesce(bool_or(token_digest=$2::bytea),false) FROM revoked
