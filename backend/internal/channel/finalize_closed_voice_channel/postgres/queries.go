package finalizeclosedvoicechannelpostgres

const selectCandidates = `
SELECT channel.id::text
FROM channels AS channel
WHERE channel.kind = 'VOICE'
  AND channel.admission_closed_at IS NOT NULL
  AND channel.archived_at IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM voice_leases AS lease
    WHERE lease.channel_id = channel.id AND lease.revoked_at IS NULL
  )
  AND NOT EXISTS (
    SELECT 1 FROM voice_sfu_revocations AS revocation
    WHERE revocation.channel_id = channel.id AND revocation.completed_at IS NULL
  )
  AND ($2::uuid IS NULL OR channel.id > $2::uuid)
ORDER BY channel.id
LIMIT $1`

const finalizeChannel = `
WITH changed AS (
    UPDATE channels AS channel
    SET archived_at = now(), updated_at = now()
    WHERE channel.id = $1
      AND channel.kind = 'VOICE'
      AND channel.admission_closed_at IS NOT NULL
      AND channel.archived_at IS NULL
      AND NOT EXISTS (
        SELECT 1 FROM voice_leases AS lease
        WHERE lease.channel_id = channel.id AND lease.revoked_at IS NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM voice_sfu_revocations AS revocation
        WHERE revocation.channel_id = channel.id AND revocation.completed_at IS NULL
      )
    RETURNING channel.id
), revised AS (
    UPDATE channel_topology_state
    SET revision = revision + 1
    WHERE singleton = TRUE AND EXISTS (SELECT 1 FROM changed)
    RETURNING revision
), audited AS (
    INSERT INTO audit_events (event_type, metadata)
    SELECT 'VOICE_CHANNEL_ARCHIVED', jsonb_build_object('channel_id', changed.id::text)
    FROM changed CROSS JOIN revised
)
SELECT revised.revision FROM revised`
