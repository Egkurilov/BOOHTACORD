CREATE INDEX IF NOT EXISTS attachments_unattached_cleanup_idx
    ON attachments (created_at, storage_key)
    WHERE state = 'UNATTACHED';
