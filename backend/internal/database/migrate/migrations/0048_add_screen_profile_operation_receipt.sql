ALTER TABLE voice_leases
    ADD COLUMN IF NOT EXISTS screen_profile_operation_revision BIGINT NOT NULL DEFAULT 0 CHECK (screen_profile_operation_revision >= 0),
    ADD COLUMN IF NOT EXISTS screen_profile_operation_hash BYTEA;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'voice_leases'::regclass
          AND conname = 'voice_leases_screen_profile_operation_receipt_check'
    ) THEN
        ALTER TABLE voice_leases ADD CONSTRAINT voice_leases_screen_profile_operation_receipt_check
            CHECK ((screen_profile_operation_revision = 0 AND screen_profile_operation_hash IS NULL)
                OR (screen_profile_operation_revision > 0 AND screen_profile_operation_hash IS NOT NULL
                    AND octet_length(screen_profile_operation_hash) = 32));
    END IF;
END;
$$;
