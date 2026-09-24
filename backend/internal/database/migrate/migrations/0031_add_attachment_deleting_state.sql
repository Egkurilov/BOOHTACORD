ALTER TABLE attachments
    DROP CONSTRAINT IF EXISTS attachments_state_check,
    DROP CONSTRAINT IF EXISTS attachments_state_timestamps;

ALTER TABLE attachments
    ADD CONSTRAINT attachments_state_check
        CHECK (state IN ('UNATTACHED', 'ATTACHED', 'HIDDEN', 'DELETING')),
    ADD CONSTRAINT attachments_state_timestamps CHECK (
        (state IN ('UNATTACHED', 'DELETING') AND attached_at IS NULL AND hidden_at IS NULL) OR
        (state = 'ATTACHED' AND attached_at IS NOT NULL AND hidden_at IS NULL) OR
        (state = 'HIDDEN' AND attached_at IS NOT NULL AND hidden_at IS NOT NULL)
    );

CREATE INDEX IF NOT EXISTS attachments_deleting_cleanup_idx
    ON attachments (created_at, storage_key)
    WHERE state = 'DELETING';
