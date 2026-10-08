ALTER TABLE users
    ADD COLUMN IF NOT EXISTS profile_revision BIGINT NOT NULL DEFAULT 1
    CHECK (profile_revision > 0);
