ALTER TABLE attachments
    ADD COLUMN IF NOT EXISTS hidden_cleanup_claim_token UUID,
    ADD COLUMN IF NOT EXISTS hidden_cleanup_claimed_at TIMESTAMPTZ;

ALTER TABLE attachments
    DROP CONSTRAINT IF EXISTS attachments_hidden_cleanup_claim_pair;
ALTER TABLE attachments
    ADD CONSTRAINT attachments_hidden_cleanup_claim_pair CHECK (
        (hidden_cleanup_claim_token IS NULL AND hidden_cleanup_claimed_at IS NULL) OR
        (state = 'HIDDEN' AND hidden_cleanup_claim_token IS NOT NULL AND hidden_cleanup_claimed_at IS NOT NULL)
    );

CREATE INDEX IF NOT EXISTS attachments_hidden_cleanup_claim_idx
    ON attachments (hidden_cleanup_claimed_at, hidden_at, id)
    WHERE state = 'HIDDEN';
