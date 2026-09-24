ALTER TABLE voice_sfu_revocations
    ADD COLUMN IF NOT EXISTS notification_claim_token UUID,
    ADD COLUMN IF NOT EXISTS notification_claimed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS notification_emitted_at TIMESTAMPTZ,
    DROP CONSTRAINT IF EXISTS voice_revocation_notification_claim_pair_check;

ALTER TABLE voice_sfu_revocations
    ADD CONSTRAINT voice_revocation_notification_claim_pair_check
        CHECK ((notification_claim_token IS NULL) = (notification_claimed_at IS NULL));

CREATE INDEX IF NOT EXISTS voice_revocation_pending_notification_index
    ON voice_sfu_revocations (requested_at, lease_id)
    WHERE notification_emitted_at IS NULL;
