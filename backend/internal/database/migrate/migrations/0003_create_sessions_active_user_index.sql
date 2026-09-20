CREATE INDEX IF NOT EXISTS sessions_active_user_id_idx ON sessions (user_id) WHERE revoked_at IS NULL;
