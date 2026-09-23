ALTER TABLE users
    ADD COLUMN IF NOT EXISTS avatar_key TEXT NULL
    CHECK (avatar_key IS NULL OR avatar_key ~ '^[0-9a-f]{64}$');
