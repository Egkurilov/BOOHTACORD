CREATE INDEX IF NOT EXISTS voice_leases_active_channel_id_idx ON voice_leases (channel_id) WHERE revoked_at IS NULL;
