CREATE TABLE IF NOT EXISTS password_resets (
    token_digest BYTEA PRIMARY KEY CHECK (octet_length(token_digest) = 32),
    user_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ
);
