CREATE UNIQUE INDEX IF NOT EXISTS voice_leases_active_user_id_idx ON voice_leases (user_id) WHERE revoked_at IS NULL;
