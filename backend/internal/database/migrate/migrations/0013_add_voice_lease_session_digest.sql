ALTER TABLE voice_leases ADD COLUMN IF NOT EXISTS session_token_digest BYTEA NOT NULL REFERENCES sessions(token_digest) ON DELETE RESTRICT CHECK (octet_length(session_token_digest) = 32);
