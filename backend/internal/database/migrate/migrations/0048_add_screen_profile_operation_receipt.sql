ALTER TABLE voice_leases
    ADD COLUMN screen_profile_operation_revision BIGINT NOT NULL DEFAULT 0 CHECK (screen_profile_operation_revision >= 0),
    ADD COLUMN screen_profile_operation_hash BYTEA,
    ADD CONSTRAINT voice_leases_screen_profile_operation_receipt_check
        CHECK ((screen_profile_operation_revision = 0 AND screen_profile_operation_hash IS NULL)
            OR (screen_profile_operation_revision > 0 AND screen_profile_operation_hash IS NOT NULL
                AND octet_length(screen_profile_operation_hash) = 32));
