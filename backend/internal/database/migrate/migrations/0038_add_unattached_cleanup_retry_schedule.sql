ALTER TABLE attachments
    ADD COLUMN IF NOT EXISTS unattached_cleanup_attempts INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS unattached_cleanup_retry_after TIMESTAMPTZ;

ALTER TABLE attachments
    DROP CONSTRAINT IF EXISTS attachments_unattached_cleanup_retry_state;
ALTER TABLE attachments
    ADD CONSTRAINT attachments_unattached_cleanup_retry_state CHECK (
        unattached_cleanup_attempts BETWEEN 0 AND 12 AND
        (state = 'DELETING' OR
         (unattached_cleanup_attempts = 0 AND unattached_cleanup_retry_after IS NULL))
    );

CREATE INDEX IF NOT EXISTS attachments_unattached_cleanup_retry_idx
    ON attachments (unattached_cleanup_retry_after, created_at, id)
    WHERE state = 'DELETING';

CREATE SEQUENCE IF NOT EXISTS attachments_unattached_cleanup_turn_seq AS BIGINT;
