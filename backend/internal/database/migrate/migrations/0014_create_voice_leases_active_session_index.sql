CREATE INDEX IF NOT EXISTS voice_leases_active_session_digest_idx ON voice_leases (session_token_digest) WHERE revoked_at IS NULL;
