ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS public_id UUID NOT NULL DEFAULT gen_random_uuid(),
    ADD COLUMN IF NOT EXISTS label TEXT NOT NULL DEFAULT 'Вход в приложение',
    ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ;
UPDATE sessions SET last_active_at=created_at WHERE last_active_at IS NULL;
ALTER TABLE sessions ALTER COLUMN last_active_at SET DEFAULT now();
ALTER TABLE sessions ALTER COLUMN last_active_at SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS sessions_public_id_unique ON sessions(public_id);
CREATE INDEX IF NOT EXISTS sessions_active_owner_created
    ON sessions(user_id,created_at DESC,public_id DESC) WHERE revoked_at IS NULL;
